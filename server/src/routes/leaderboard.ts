import { Hono } from 'hono';
import db from '../db/index';
import { runs } from '../db/schema';
import { asc, eq, sql, and, lt } from 'drizzle-orm';
import { PgColumn } from 'drizzle-orm/pg-core';
import { version_compare, steam_auth } from '../middleware';
import { z } from 'zod';
import { describeRoute } from 'hono-openapi';
import { resolver, validator as zValidator } from 'hono-openapi/zod';
import { discord_client, DISCORD_CHANNEL_ID } from '../index';
import { ChannelType } from 'discord.js';
import { type Variables } from '../index';
import { hide_route } from './common';

const app = new Hono<{ Variables: Variables }>();

const RunInput = z.object({
  recording: z.string(),
  map_name: z.string(),
  time_ms: z.number(),
  username: z.string(),
});

function describe_leaderboard_route<T extends z.ZodTypeAny>(
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
          'application/json': {
            schema: resolver(success_schema),
          },
        },
      },
      400: {
        description: 'Error',
        content: {
          'application/json': {
            schema: resolver(
              z.object({
                error: z.string(),
              })
            ),
          },
        },
      },
    },
  });
}

const RecordingResponse = z.object({
  data: z.string(),
});

app.get(
  '/maps/:map_name/recording/:steam_id',
  describe_leaderboard_route(
    'Fetches the recording data associated with a specific run by a player on a map. Useful for replay or analysis purposes.',
    RecordingResponse
  ),
  async (c) => {
    const map_name = c.req.param('map_name');
    const steam_id = c.req.param('steam_id');

    try {
      const run_result = await db
        .select({
          recording: runs.recording,
        })
        .from(runs)
        .where(and(eq(runs.steam_id, steam_id), eq(runs.map_name, map_name)));

      if (!run_result.length) {
        return c.json({ error: 'Could not find recording.' }, 400);
      }

      const data: z.infer<typeof RecordingResponse> = {
        data: run_result[0].recording,
      };
      return c.json(data);
    } catch (e) {
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

const PlayerRunsResponse = z.object({
  data: z.array(
    z.object({
      time_ms: z.number(),
      map_name: z.string(),
      created_at: z.string(),
      position: z.number(),
      total: z.number(),
    })
  ),
});

app.get(
  '/players/:steam_id/runs',
  describe_leaderboard_route(
    'Fetches all runs for the specified player by their Steam ID. Returns details like time, map name, and when the run was recorded, along with the player’s position and total number of runs on each map.',
    PlayerRunsResponse
  ),
  async (c) => {
    const steam_id = c.req.param('steam_id');

    try {
      console.log(steam_id);
      const player_runs = await db
        .select({
          time_ms: runs.time_ms,
          map_name: runs.map_name,
          created_at: runs.created_at,
        })
        .from(runs)
        .where(eq(runs.steam_id, steam_id));

      const full_run_info = await Promise.all(
        player_runs.map(async (run) => ({
          ...run,
          created_at: format_date(run.created_at),
          position: await get_player_position(run.time_ms, run.map_name),
          total: await get_run_count(run.map_name),
        }))
      );

      const data: z.infer<typeof PlayerRunsResponse> = { data: full_run_info };
      console.log(data);
      return c.json(data);
    } catch (e) {
      console.log(e);
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

const MapRunsResponse = z.object({
  data: z.object({
    runs: z.array(
      z.object({
        time_ms: z.number(),
        steam_id: z.string(),
        created_at: z.string(),
        username: z.string(),
      })
    ),
    total: z.number(),
  }),
});

function format_date(date: Date) {
  return date.toISOString().slice(0, '2000-00-00'.length);
}

app.get(
  '/maps/:map_name/runs',
  describe_leaderboard_route(
    'Retrieves a paginated leaderboard of runs for the specified map. Returns run details sorted by time in ascending order. Accepts a page query parameter to navigate through leaderboard pages.',
    MapRunsResponse
  ),
  async (c) => {
    const map_name = c.req.param('map_name');
    const page_string = c.req.query('page');

    let page = 0;
    if (page_string) page = parseInt(page_string);

    try {
      const runs_result = await db
        .select({
          time_ms: runs.time_ms,
          steam_id: runs.steam_id,
          username: runs.username,
          created_at: runs.created_at,
        })
        .from(runs)
        .where(eq(runs.map_name, map_name))
        .orderBy(asc(runs.time_ms))
        .limit(10)
        .offset(page * 10);

      const formatted_result = runs_result.map((run) => ({
        ...run,
        created_at: format_date(run.created_at),
      }));

      const data: z.infer<typeof MapRunsResponse> = {
        data: {
          runs: formatted_result,
          total: await get_run_count(map_name),
        },
      };
      return c.json(data);
    } catch (e) {
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

async function get_run_count(map_name: string) {
  return (
    await db
      .select({ count: sql`COUNT(*)`.mapWith(Number) })
      .from(runs)
      .where(eq(runs.map_name, map_name))
  )[0].count;
}

async function get_player_position(time_ms: number, map_name: string) {
  return (
    (
      await db
        .select({ count: sql`COUNT(*)`.mapWith(Number) })
        .from(runs)
        .where(and(eq(runs.map_name, map_name), lt(runs.time_ms, time_ms)))
    )[0].count + 1
  );
}

const PlayerMapResponse = z.object({
  data: z.object({
    time_ms: z.number(),
    steam_id: z.string(),
    created_at: z.string(),
    username: z.string(),
    position: z.number(),
  }),
});

app.get(
  '/maps/:map_name/runs/:steam_id',
  describe_leaderboard_route(
    "Gets detailed information about a specific player's run on a given map, including the run time, username, and their leaderboard position.",
    PlayerMapResponse
  ),
  async (c) => {
    const map_name = c.req.param('map_name');
    const steam_id = c.req.param('steam_id');

    try {
      const run_result = await db
        .select({
          time_ms: runs.time_ms,
          steam_id: runs.steam_id,
          username: runs.username,
          created_at: runs.created_at,
        })
        .from(runs)
        .where(and(eq(runs.map_name, map_name), eq(runs.steam_id, steam_id)));

      if (!run_result.length) {
        return c.json(
          { error: 'Could not find a run with the provided information.' },
          400
        );
      }

      const time = run_result[0].time_ms;
      const result = {
        ...run_result[0],
        created_at: format_date(run_result[0].created_at),
        position: await get_player_position(time, map_name),
      };

      const data: z.infer<typeof PlayerMapResponse> = { data: result };
      console.log(data);
      return c.json(data);
    } catch (e) {
      return c.json({ error: 'Internal server error ' }, 500);
    }
  }
);

async function send_discord_update(
  newTime: number,
  player: string,
  mapName: string,
  position: number
) {
  try {
    const channel = await discord_client.channels.fetch(DISCORD_CHANNEL_ID);
    if (!channel || !channel.isTextBased()) {
      throw new Error('Channel not configured');
    }
    if (channel.type === ChannelType.GuildText) {
      await channel.send(
        `Player ${player} has achieved ${(() => {
          switch (position) {
            case 1:
              return 'first';
            case 2:
              return 'second';
            case 3:
              return 'third';
            case 4:
              return 'fourth';
            case 5:
              return 'fifth';
            default:
              return `${position}th`;
          }
        })()} place on ${mapName} with a time of ${(newTime / 1000).toFixed(3)} seconds!`
      );
    }
  } catch (e) {
    return;
  }
}

app.post(
  '/runs',
  zValidator('json', RunInput),
  hide_route(),
  steam_auth,
  version_compare,
  async (c) => {
    const body = c.req.valid('json');

    if (body.recording.length >= 474854) {
      // 474864 = 370s
      return c.json({ error: 'Run was too long.' }, 400);
    }

    const pb_result = await db
      .select({
        time_ms: runs.time_ms,
      })
      .from(runs)
      .where(
        and(
          eq(runs.map_name, body.map_name),
          eq(runs.steam_id, c.get('steam_id'))
        )
      )
      .limit(1);

    const pb = pb_result[0] ? pb_result[0].time_ms : Infinity;

    try {
      await db
        .insert(runs)
        .values({
          steam_id: c.get('steam_id'),
          map_name: body.map_name,
          recording: body.recording,
          time_ms: body.time_ms,
          username: body.username,
        })
        .onConflictDoUpdate({
          target: [runs.steam_id, runs.map_name],
          set: {
            time_ms: body.time_ms,
            recording: body.recording,
            username: body.username,
            created_at: new Date(),
          },
          setWhere: sql`${runs.time_ms} > ${body.time_ms}`,
        });

      const position = await get_player_position(body.time_ms, body.map_name);

      if (position <= 5 && body.time_ms < pb) {
        send_discord_update(
          body.time_ms,
          body.username,
          body.map_name,
          position
        );
      }

      return c.json({ data: 'success' });
    } catch (e) {
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

export default app;
