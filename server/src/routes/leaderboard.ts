import { Hono } from 'hono'
import db from '../db/index.ts'
import { z } from 'zod';
import { runs } from '../db/schema.ts';
import { desc, asc, eq, sql } from 'drizzle-orm';
import { zValidator } from '@hono/zod-validator'

const app = new Hono();

const RunInput = z.object({
	steam_id: z.number(),
	recording: z.string(),
	map_name: z.string(),
	time_ms: z.number(),
});

app.get('/:map_name', async (c) => {
	const mapName = c.req.param('map_name');
	const page = parseInt(c.req.query('page')!);

	const runsResult = await db.select({
															time_ms: runs.time_ms,
															steam_id: runs.steam_id
														})
														.from(runs)
														.where(eq(runs.map_name, mapName))
														.orderBy(asc(runs.time_ms))
														.limit(10)
														.offset(page * 10)
	
	return c.json({ data: runsResult });
});

app.post('/', 
	zValidator(
		'json',
		RunInput,
	),
	async (c) => {
		const body = c.req.valid('json');

		// TODO: Accept steam ticket instead of the steam_id, then verify the player
		// Accept the player's name as well
		
		await db.insert(runs).values({
			steam_id: body.steam_id,
			map_name: body.map_name,
			recording: body.recording,
			time_ms: body.time_ms,
		}).onConflictDoUpdate({
			target: [runs.steam_id, runs.map_name],
			set: {
				time_ms: body.time_ms,
				recording: body.recording,
			},
			setWhere: sql`${runs.time_ms} > ${body.time_ms}`
		})

		return c.json({ success: true })
	}
);

export default app;
