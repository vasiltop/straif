import { Hono } from 'hono';
import db from '../db/index';
import { endless_runs } from '../db/schema';
import { and, desc, eq, gt, sql } from 'drizzle-orm';
import { version_compare, steam_auth, ban_auth } from '../middleware';
import { z } from 'zod';
import { describeRoute, resolver, validator as zValidator } from 'hono-openapi';
import { type Variables } from '../index';
import { hide_route } from './common';

const app = new Hono<{ Variables: Variables }>();

const EndlessRunInput = z.object({
  blocks_reached: z.number().int().min(0),
  username: z.string().trim().min(1).max(64),
});

const PaginationQuery = z.object({
  page: z.coerce.number().int().min(0).default(0),
});

const MapNameParam = z.object({
  map_name: z.string(),
});

function describe_endless_route<T extends z.ZodTypeAny>(
  description: string,
  success_schema: T
) {
  return describeRoute({
    description,
    tags: ['leaderboard'],
    responses: {
      200: {
        description: 'Successful',
        content: {
          'application/json': { schema: resolver(success_schema) },
        },
      },
      400: {
        description: 'Error',
        content: {
          'application/json': {
            schema: resolver(z.object({ error: z.string() })),
          },
        },
      },
    },
  });
}

const EndlessRun = z.object({
  steam_id: z.string(),
  username: z.string(),
  blocks_reached: z.number(),
  created_at: z.string(),
  position: z.number().int().min(1),
});

const EndlessRunsResponse = z.object({
  data: z.object({
    runs: z.array(EndlessRun),
    total: z.number().int().min(0),
  }),
});

function format_date(date: Date) {
  return date.toISOString().slice(0, '2000-00-00'.length);
}

async function get_run_count(map_name: string) {
  return (
    await db
      .select({ count: sql`COUNT(*)`.mapWith(Number) })
      .from(endless_runs)
      .where(eq(endless_runs.map_name, map_name))
  )[0].count;
}

async function get_player_position(map_name: string, blocks_reached: number) {
  return (
    (
      await db
        .select({ count: sql`COUNT(*)`.mapWith(Number) })
        .from(endless_runs)
        .where(
          and(
            eq(endless_runs.map_name, map_name),
            gt(endless_runs.blocks_reached, blocks_reached)
          )
        )
    )[0].count + 1
  );
}

app.get(
  '/maps/:map_name/runs',
  describe_endless_route(
    'Retrieves a paginated endless leaderboard for the specified map. Runs are sorted by blocks reached descending. Accepts a page query parameter.',
    EndlessRunsResponse
  ),
  zValidator('param', MapNameParam),
  zValidator('query', PaginationQuery),
  async (c) => {
    const map_name = c.req.valid('param').map_name;
    const { page } = c.req.valid('query');
    const offset = page * 10;

    try {
      const [runs_result, total] = await Promise.all([
        db
          .select({
            steam_id: endless_runs.steam_id,
            username: endless_runs.username,
            blocks_reached: endless_runs.blocks_reached,
            created_at: endless_runs.created_at,
          })
          .from(endless_runs)
          .where(eq(endless_runs.map_name, map_name))
          .orderBy(
            desc(endless_runs.blocks_reached),
            endless_runs.steam_id
          )
          .limit(10)
          .offset(offset),
        get_run_count(map_name),
      ]);

      const runs = runs_result.map((run, index) => ({
        ...run,
        created_at: format_date(run.created_at),
        position: offset + index + 1,
      }));

      const data: z.infer<typeof EndlessRunsResponse> = {
        data: { runs, total },
      };
      return c.json(data);
    } catch (e) {
      console.log(e);
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

app.post(
  '/maps/:map_name/runs',
  zValidator('param', MapNameParam),
  zValidator('json', EndlessRunInput),
  hide_route(),
  steam_auth,
  ban_auth,
  version_compare,
  async (c) => {
    const map_name = c.req.valid('param').map_name;
    const body = c.req.valid('json');
    const steam_id = c.get('steam_id');

    try {
      await db
        .insert(endless_runs)
        .values({
          steam_id,
          map_name,
          username: body.username,
          blocks_reached: body.blocks_reached,
        })
        .onConflictDoUpdate({
          target: [endless_runs.map_name, endless_runs.steam_id],
          set: {
            username: body.username,
            blocks_reached: body.blocks_reached,
            created_at: new Date(),
          },
          setWhere: sql`${endless_runs.blocks_reached} < ${body.blocks_reached}`,
        });

      const position = await get_player_position(
        map_name,
        body.blocks_reached
      );

      return c.json({
        data: `Reached ${body.blocks_reached} blocks. Leaderboard position: ${position}.`,
      });
    } catch (e) {
      console.log(e);
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

export default app;
