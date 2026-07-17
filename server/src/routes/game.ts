import { Hono } from 'hono';
import { type Variables } from '../index';
import { version_compare, steam_auth } from '../middleware';
import { is_admin } from '../players';
import { hide_route } from './common';
import db from '../db';
import { world_records } from '../db/schema';
import { asc, desc, gt } from 'drizzle-orm';
import { parse_world_record_cursor } from '../world_records';

export const server_state = {
  maintenance: false,
};

const app = new Hono<{ Variables: Variables }>();

app.get('/heartbeat', hide_route(), steam_auth, version_compare, async (c) => {
  const steam_id = c.get('steam_id');
  const admin = await is_admin(steam_id);
  const parsed_cursor = parse_world_record_cursor(
    c.req.query('world_record_since')
  );

  if (!parsed_cursor.success) {
    return c.json({ error: 'Invalid world-record cursor.' }, 400);
  }

  let record_results: (typeof world_records.$inferSelect)[] = [];
  let world_record_cursor: number;
  let world_record_has_more = false;

  if (parsed_cursor.cursor === null) {
    const latest_record = await db
      .select({ id: world_records.id })
      .from(world_records)
      .orderBy(desc(world_records.id))
      .limit(1);
    world_record_cursor = latest_record[0]?.id ?? 0;
  } else {
    const pending_records = await db
      .select()
      .from(world_records)
      .where(gt(world_records.id, parsed_cursor.cursor))
      .orderBy(asc(world_records.id))
      .limit(101);
    world_record_has_more = pending_records.length > 100;
    record_results = pending_records.slice(0, 100);
    world_record_cursor =
      record_results[record_results.length - 1]?.id ?? parsed_cursor.cursor;
  }

  return c.json({
    data: {
      admin,
      maintenance: server_state.maintenance,
      world_record_cursor,
      world_record_has_more,
      world_records: record_results,
    },
  });
});

export default app;
