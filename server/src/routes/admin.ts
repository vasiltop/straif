import { Hono } from 'hono';
import { type Variables } from '../index';
import db from '../db/index';
import { server_state } from './game';
import { admin_auth } from '../middleware';
import { z } from 'zod';
import { validator as zValidator } from 'hono-openapi/zod';
import { admins } from '../db/schema';
import { eq } from 'drizzle-orm';
import { is_admin } from '../players';
import { hide_route } from './common';

const app = new Hono<{ Variables: Variables }>();

const BooleanInput = z.object({
  new_value: z.boolean(),
});

app.post(
  '/maintenance',
  zValidator('json', BooleanInput),
  admin_auth,
  hide_route(),
  async (c) => {
    const maintenance = c.req.valid('json').new_value;
    server_state.maintenance = maintenance;
  }
);

app.post(
  '/:steam_id',
  admin_auth,
  hide_route(),
  zValidator('json', BooleanInput),
  async (c) => {
    const steam_id = c.req.param('steam_id');
    const new_value = c.req.valid('json').new_value;
    const admin = is_admin(steam_id);

    if (admin && !new_value) {
      await db.delete(admins).where(eq(admins.steam_id, steam_id));
    } else if (!admin && new_value) {
      await db.insert(admins).values({
        steam_id,
      });
    }
  }
);

app.get('/player/:steam_id', hide_route(), admin_auth, async (c) => {
  const steam_id = c.req.param('steam_id');
  const admin = is_admin(steam_id);

  return c.json({
    admin,
  });
});

export default app;
