import { serve } from '@hono/node-server'
import { cors } from 'hono/cors';
import { admin_auth, version_compare } from './middleware.ts';
import { Hono } from 'hono';
import { swaggerUI } from '@hono/swagger-ui';
import { openAPISpecs } from 'hono-openapi';
import leaderboard from './routes/leaderboard.ts'
import {
	Client,
	GatewayIntentBits,
} from "discord.js";

const app = new Hono()

app.use('*', cors({
	origin: '*',
	allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
	allowHeaders: ['Content-Type', 'Authorization'],
}));

app.route('/leaderboard', leaderboard);

const open_api_doc = {
	documentation: {
		info: {
			title: 'Straif API',
			version: '0.0.3',
		},
		servers: [
			{
				url: "https://straifapi.pumped.software",
			}
		]
	}
};

app.get(
	'/openapi',
	openAPISpecs(app, open_api_doc),
);

app.get(
	'/docs',
	swaggerUI({ url: '/openapi' })
);

app.get(
	'/version',
	version_compare,
	async (c) => {
		return c.text("Correct version");
	}
);

app.get(
	'/admin',
	admin_auth,
	async (c) => { 
		return c.text("Admin");
	}
);

serve({
	fetch: app.fetch,
	port: 3000
}, (info) => {
	console.log(`Server is running on http://localhost:${info.port}`)
});

export const discord_client = new Client({
	intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages],
});

discord_client.login(process.env.DISCORD_TOKEN);

export const DISCORD_CHANNEL_ID = process.env.CHANNEL_ID!;

discord_client.on("ready", () => {
	console.log(`Logged in as ${discord_client.user?.tag}`);
});
