import 'dotenv/config'
import { createMiddleware } from 'hono/factory';
import db from './db/index.ts';
import { admins } from './db/schema.ts';
import { eq } from 'drizzle-orm';

const STEAM_API_KEY = process.env.STEAM_API_KEY!;

const BASE_URL = "https://api.steampowered.com"

async function get_steam_id_from_ticket(ticket: string): Promise<string> {
	const params = new URLSearchParams({
		key: STEAM_API_KEY,
		appid: '3850480',
		ticket,
		identity: 'munost'
	});

	const url = BASE_URL + `/ISteamUserAuth/AuthenticateUserTicket/v1/?${params.toString()}`;
	const res = await fetch(url);
	const json = await res.json();
	
	// TODO: not safe
	return json.response.params.steamid;
}

export const version_compare = createMiddleware(async (c, next) => {
	const version = c.req.header('version')

	if (!version) {
		return c.json({ error: "Invalid Version" }, 401);
	}

	console.log(`Comparing server hash ${process.env.VERSION} and ${version}`)

	if (version != process.env.VERSION) {
		return c.json({ error: "Invalid Version" }, 401);
	}

	return next();
});

export const steam_auth = createMiddleware(async (c, next) => {
	const auth_ticket = c.req.header('auth-ticket');

	if (!auth_ticket) {
		return c.json({ error: "Invalid authentication ticket" }, 401);
	}

	c.set('steam_id', await get_steam_id_from_ticket(auth_ticket));

	return next();
});

export const admin_auth = createMiddleware(async (c, next) => {
	const auth_ticket = c.req.header('auth-ticket');

	if (!auth_ticket) {
		return c.json({ error: "You are not an administrator" }, 401);
	}

	const steam_id = await get_steam_id_from_ticket(auth_ticket);

	const res = await db.select().from(admins).where(eq(admins.steam_id, steam_id))

	if (res.length == 0) {
		return c.body(null, 401);
	}

	return next();
});
