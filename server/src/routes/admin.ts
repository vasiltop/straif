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

const MUNOST_STEAM_ID = '76561198377195635';
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

    return c.json({
      data: `Maintenace was toggled, new value: ${maintenance}`,
    });
  }
);

app.post(
  '/:steam_id',
  admin_auth,
  hide_route(),
  zValidator('json', BooleanInput),
  async (c) => {
    const steam_id = c.req.param('steam_id');

    if (steam_id === MUNOST_STEAM_ID) {
      return c.json({ error: 'Nice try' }, 400);
    }

    const new_value = c.req.valid('json').new_value;
    const admin = await is_admin(steam_id);

    if (admin && !new_value) {
      await db.delete(admins).where(eq(admins.steam_id, steam_id));
    } else if (!admin && new_value) {
      await db.insert(admins).values({
        steam_id,
      });
    }

    return c.json({
      data: `Player's admin was toggled, new value: ${!admin}`,
    });
  }
);

app.get('/player/:steam_id', hide_route(), admin_auth, async (c) => {
  const steam_id = c.req.param('steam_id');
  const admin = await is_admin(steam_id);

  return c.json({
    data: admin,
  });
});

export default app;
