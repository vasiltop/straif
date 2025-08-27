import { Hono } from 'hono';
import { z } from 'zod';
import { resolver, validator as zValidator } from 'hono-openapi/zod';

const app = new Hono();

const SERVER_HEALTH_TIMER = 1000 * 10; // server must be down for 10 secs min before deletion

setInterval(check_server_health, 1000 * 10); // check every 3 seconds

function check_server_health() {
  const d = Date.now();
  const latest = d - SERVER_HEALTH_TIMER;

  servers.forEach((server, name) => {
    if (server.last_ping.getTime() < latest) {
      servers.delete(name);
    }
  });
}

const ServerInput = z.object({
  port: z.number(),
  name: z.string(),
  mode: z.string(),
  map: z.string(),
  player_count: z.number(),
  max_players: z.number(),
});

const ServerExtend = ServerInput.extend({
  last_ping: z.coerce.date(),
  ip: z.string(),
});

type Server = z.infer<typeof ServerExtend>;

// maps the server name to the info
const servers = new Map<string, Server>();

app.post('/', zValidator('json', ServerInput), async (c) => {
  const body = c.req.valid('json');

  if (servers.has(body.name)) {
    servers.get(body.name).last_ping = new Date();
    return c.body(null, 200);
  }

  const x_forwarded_for = c.req.header('x-forwarded-for');
  let ip: string;

  if (x_forwarded_for) {
    ip = x_forwarded_for.split(',')[0].trim();
  } else {
    ip = '127.0.0.1';
  }

  const server: Server = {
    ...body,
    ip,
    last_ping: new Date(),
  };

  servers.set(body.name, server);

  return c.body(null, 200);
});

app.get('/', async (c) => {
  return c.json({
    data: Array.from(servers.values()),
  });
});

export default app;
