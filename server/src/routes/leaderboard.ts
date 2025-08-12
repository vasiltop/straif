import { Hono } from 'hono'
import db from '../db/index.ts'
import { runs } from '../db/schema.ts';
import { asc, eq, sql, and, lt } from 'drizzle-orm';
import { admin_auth, version_compare, steam_auth } from '../middleware.ts';

import { z } from 'zod';
import { describeRoute } from 'hono-openapi';
import { resolver, validator as zValidator } from 'hono-openapi/zod';

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
	'/:steam_id/runs',
	describeRoute({
		description: 'Get all runs for a player with their leaderboard position and total runs per map.',
		tags: ["leaderboard"],
		responses: {
			200: {
				description: 'Succesful',
				content: {
					'application/json': {
						schema: resolver(z.array(z.object({
							position: z.number(),
							total: z.number(),
							time_ms: z.number(),
							map_name: z.string(),
						}))),
					}
				}
			}
		}
	}),
	async (c) => {
		const steam_id = c.req.param('steam_id');

		try {
			const player_runs = await db.select({
				time_ms: runs.time_ms,
				map_name: runs.map_name,
			}).from(runs).where(
				eq(runs.steam_id, steam_id)
			);

			const full_run_info = await Promise.all(player_runs.map(async run => ({
				...run,
				position: await get_player_position(run.time_ms, run.map_name),
				total: await get_run_count(run.map_name)
			})));

			return c.json({
				data: full_run_info,
			});

		} catch (e) {
			return c.json({ error: "Internal server error" }, 500);
		}
	}
);

app.get(
	'/:map_name',
	describeRoute({
		description: "A paginated retrieval of a map's runs.",
		tags: ["leaderboard"],
		parameters: [
			{
				name: 'page',
				in: 'query',
				required: true,
				schema: resolver(z.number()),
			}
		],
		responses: {
			200: {
				description: 'Successful',
				content: {
					'application/json': {
						schema: resolver(
							z.object({
								data: z.array(
									z.object({
										position: z.number(),
										total: z.number(),
										time_ms: z.number(),
										map_name: z.string(),
									})
								),
								count: z.number(),
							})
						)
					},
				},
			},
		}
	}),
	async (c) => {
		const map_name = c.req.param('map_name');
		const page_string = c.req.query('page');

		let page = 0;

		if (page_string)
			page = parseInt(page_string);

		try {
			const runs_result = await db.select({
				time_ms: runs.time_ms,
				steam_id: runs.steam_id,
				username: runs.username,
				created_at: runs.created_at,
			})
				.from(runs)
				.where(eq(runs.map_name, map_name))
				.orderBy(asc(runs.time_ms))
				.limit(10)
				.offset(page * 10)

			return c.json({
				data: runs_result,
				count: await get_run_count(map_name),
			});
		} catch (e) {
			return c.json({ error: "Internal server error" }, 500);
		}
	});

async function get_run_count(map_name: string): Promise<number> {
	const [count_result] = await db.select({
		count: sql`COUNT(*)`.mapWith(Number),
	}).from(runs).where(eq(runs.map_name, map_name));

	return count_result.count;
}

app.get(
	'/:map_name/:steam_id',
	describeRoute({
		description: "Get a players time on a specific map.",
		tags: ["leaderboard"],
		responses: {
			200: {
				description: 'Succesful',
				content: {
					"Application/json": {
						schema: resolver(z.object({
							time_ms: z.number(),
							steam_id: z.string(),
							username: z.string(),
							created_at: z.string(),
							position: z.number(),
						}))
					}
				}
			},
			400: {
				description: 'Run does not exist',
				content: {
					"Application/json": {
						schema: resolver(z.object({
							error: z.string(),
						}))
					}
				}
			}
		}
	}),
	async (c) => {
		const map_name = c.req.param('map_name');
		const steam_id = c.req.param('steam_id');

		try {
			const run_result = await db.select({
				time_ms: runs.time_ms,
				steam_id: runs.steam_id,
				username: runs.username,
				created_at: runs.created_at
			})
				.from(runs)
				.where(and(eq(runs.map_name, map_name), eq(runs.steam_id, steam_id)));

			if (!run_result.length) {
				return c.json({ error: "Could not find a run with the provided information." }, 400);
			}

			const time = run_result[0].time_ms;

			return c.json({
				data: {
					...run_result[0],
					position: await get_player_position(time, map_name),
				}
			})

		} catch (e) {
			return c.json({ error: "Internal server error " }, 500);
		}
	});

async function get_player_position(time: number, map: string): Promise<number> {
	const [better_runs] =
		await db.select({ count: sql`COUNT(*)`.mapWith(Number) })
			.from(runs)
			.where(
				and(
					eq(runs.map_name, map),
					lt(runs.time_ms, time)
				)
			);

	return better_runs.count + 1;
}

app.post('/',
	zValidator(
		'json',
		RunInput,
	),
	describeRoute({
		hide: true,
	}),
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
