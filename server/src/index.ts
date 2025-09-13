import { serve } from '@hono/node-server';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { swaggerUI } from '@hono/swagger-ui';
import { openAPISpecs } from 'hono-openapi';
import leaderboard from './routes/leaderboard';
import admin from './routes/admin';
import game from './routes/game';
import browser from './routes/browser';
import { Client, GatewayIntentBits } from 'discord.js';

export type Variables = {
  steam_id: string;
};

const app = new Hono();

app.use(
  '*',
  cors({
    origin: '*',
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization'],
  })
);

app.route('/leaderboard', leaderboard);
app.route('/admin', admin);
app.route('/game', game);
app.route('/browser', browser);

const open_api_doc = {
  documentation: {
    info: {
      title: 'Straif API',
      version: '0.0.3',
    },
    servers: [
      {
        url: 'https://straifapi.pumped.software',
      },
    ],
  },
};

app.get('/openapi', openAPISpecs(app, open_api_doc));
app.get('/docs', swaggerUI({ url: '/openapi' }));

serve(
  {
    fetch: app.fetch,
    port: parseInt(process.env.PORT!),
  },
  (info) => {
    console.log(`Server is running on http://localhost:${info.port}`);
  }
);

export const discord_client = new Client({
  intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages],
});

export const DISCORD_CHANNEL_ID = process.env.CHANNEL_ID!;

discord_client.on('ready', () => {
  console.log(`Logged in as ${discord_client.user?.tag}`);
});

discord_client.login(process.env.DISCORD_TOKEN);
