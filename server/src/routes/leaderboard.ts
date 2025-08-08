import { Hono } from 'hono'
import db from '../db/index.ts'
import { z } from 'zod';
import { runs } from '../db/schema.ts';
import { asc, eq, sql, and, lt } from 'drizzle-orm';
import { zValidator } from '@hono/zod-validator'
import { admin_auth, version_compare, steam_auth } from '../middleware.ts';

type Variables = {
	steam_id: string,
}

const app = new Hono<{ Variables: Variables }>();

const RunInput = z.object({
	recording: z.string(),
	map_name: z.string(),
	time_ms: z.number(),
	username: z.string(),
});

app.get(
	'/:map_name/:steam_id/recording',
	admin_auth,
	async (c) => {
		const map_name = c.req.param('map_name');
		const steam_id = c.req.param('steam_id');

		try {
			const run_result = await db.select({
				recording: runs.recording,
			}).from(runs).where(
				and(
					eq(runs.steam_id, steam_id),
					eq(runs.map_name, map_name)
				)
			);
			return c.json({ data: run_result[0] });
		} catch (e) {
			return c.json({ error: "Internal server error" }, 500);
		}
	}
);

app.get(
	'/version',
	version_compare,
);

app.get(
	'/:steam_id/runs',
	async (c) => {
		const steam_id = c.req.param('steam_id');

		try {
			const player_runs = await db.select({
				time_ms: runs.time_ms,
				map_name: runs.map_name,
			}).from(runs).where(
				eq(runs.steam_id, steam_id)
			);

			return c.json({ data: player_runs });
		} catch (e) {
			return c.json({ error: "Internal server error" }, 500);
		}
	}
)

app.get(
	'/admin',
	admin_auth,
)

app.get('/:map_name', async (c) => {
	const mapName = c.req.param('map_name');
	const page = parseInt(c.req.query('page')!);

	try {
		const runsResult = await db.select({
			time_ms: runs.time_ms,
			steam_id: runs.steam_id,
			username: runs.username,
			created_at: runs.created_at,
		})
			.from(runs)
			.where(eq(runs.map_name, mapName))
			.orderBy(asc(runs.time_ms))
			.limit(10)
			.offset(page * 10)

		const countResult = await db.select({
			count: sql`COUNT(*)`,
		}).from(runs).where(eq(runs.map_name, mapName));

		return c.json(
			{ 
				data: runsResult,
					count: parseInt(countResult[0].count),
			});
	} catch (e) {
		console.log(e);
		return c.json({ error: "Internal server error" }, 500);
	}
});

app.get('/:map_name/:steam_id', async (c) => {
	const mapName = c.req.param('map_name');
	const steamId = c.req.param('steam_id');

	try {
		const runResult = await db.select({
			time_ms: runs.time_ms,
			steam_id: runs.steam_id,
			username: runs.username,
			created_at: runs.created_at
		})
			.from(runs)
			.where(and(eq(runs.map_name, mapName), eq(runs.steam_id, steamId)));

		if (runResult.length === 0) {
			return c.json({ error: "Could not find a run with the provided information." });
		}

		const userTime = runResult[0].time_ms;

		const betterRuns = await db.select({
			count: sql<number>`count(*)`
		})
			.from(runs)
			.where(and(eq(runs.map_name, mapName), lt(runs.time_ms, userTime)));

		const position = parseInt(betterRuns[0].count) + 1;

		return c.json({
			data: {
				...runResult[0],
				position,
			}
		})

	} catch (e) {
		return c.json({ error: "Internal server error " }, 500);
	}
});

app.post('/',
	zValidator(
		'json',
		RunInput,
	),
	steam_auth,
	version_compare,
	async (c) => {
		const body = c.req.valid('json');
	
		if (body.recording.length >= 474854) {
			// 474864 = 370s
			return c.json({ error: "Run was too long." }, 400);
		}

		try {
			await db.insert(runs).values({
				steam_id: c.get('steam_id'),
				map_name: body.map_name,
				recording: body.recording,
				time_ms: body.time_ms,
				username: body.username,
			}).onConflictDoUpdate({
				target: [runs.steam_id, runs.map_name],
				set: {
					time_ms: body.time_ms,
					recording: body.recording,
					username: body.username,
					created_at: new Date(),
				},
				setWhere: sql`${runs.time_ms} > ${body.time_ms}`
			});

			return c.json({ success: true });
		} catch (e) {
			return c.json({ error: "Internal server error" }, 500);
		}
	}
);

export default app;
