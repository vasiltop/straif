import { Hono } from 'hono'
import db from '../db/index.ts'
import { z } from 'zod';
import { runs } from '../db/schema.ts';
import { desc, asc, eq, sql } from 'drizzle-orm';
import { zValidator } from '@hono/zod-validator'
import { steam_auth } from '../middleware.ts';

type Variables = {
  steam_id: number 
}

const app = new Hono<{ Variables: Variables }>();

const RunInput = z.object({
	recording: z.string(),
	map_name: z.string(),
	time_ms: z.number(),
	username: z.string(),
});

app.get('/:map_name', async (c) => {
	const mapName = c.req.param('map_name');
	const page = parseInt(c.req.query('page')!);

	const runsResult = await db.select({
															time_ms: runs.time_ms,
															steam_id: runs.steam_id,
															username: runs.username
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
	steam_auth,
	async (c) => {
		const body = c.req.valid('json');
		
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
		})

		return c.json({ success: true })
	}
);

export default app;
