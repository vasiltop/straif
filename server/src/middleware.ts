import 'dotenv/config'
import { createMiddleware } from 'hono/factory';

const STEAM_API_KEY = process.env.STEAM_API_KEY!;

const BASE_URL = "https://api.steampowered.com"

export const steam_auth = createMiddleware(async (c, next) => {
	const auth_ticket = c.req.header('auth-ticket');

	if (!auth_ticket) {
		return c.body(null, 401);
	}

	const params = new URLSearchParams({
		key: STEAM_API_KEY,
		appid: '480',
		ticket: auth_ticket,
		identify: 'munost'
	});

	const url = BASE_URL + `/ISteamUserAuth/AuthenticateUserTicket/v1/?${params.toString()}`;
	const res = await fetch(url);
	const json = await res.json();

	c.set('steam_id', parseInt(json.response.params.steamid));

	return next();
});
