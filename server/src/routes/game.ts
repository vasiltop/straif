import { Hono } from 'hono';
import { type Variables } from '../index';
import { version_compare, steam_auth } from '../middleware';
import { is_admin } from '../players';
import { hide_route } from './common';
import { recent_world_records } from '../world_records';

export const server_state = {
  maintenance: false,
};

const app = new Hono<{ Variables: Variables }>();

app.get('/heartbeat', hide_route(), steam_auth, version_compare, async (c) => {
  const steam_id = c.get('steam_id');
  const admin = await is_admin(steam_id);

  return c.json({
    data: {
      admin,
      maintenance: server_state.maintenance,
      world_records: recent_world_records.list(),
    },
  });
});

export default app;
