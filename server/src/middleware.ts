import 'dotenv/config';
import { createMiddleware } from 'hono/factory';
import { is_admin, value_banned } from './players';

const STEAM_API_KEY = process.env.STEAM_API_KEY!;

const BASE_URL = 'https://partner.steam-api.com';

async function get_steam_id_from_ticket(ticket: string): Promise<string> {
  const params = new URLSearchParams({
    key: STEAM_API_KEY,
    appid: '3850480',
    ticket,
    identity: 'munost',
  });

  const url =
    BASE_URL +
    `/ISteamUserAuth/AuthenticateUserTicket/v1/?${params.toString()}`;
  const res = await fetch(url);
  const json = await res.json();

  if (!json.response.params) {
    return '';
  }

  return json.response.params.steamid;
}

export const version_compare = createMiddleware(async (c, next) => {
  const version = c.req.header('version');

  if (!version) {
    return c.json({ error: 'Invalid Version' }, 401);
  }

  if (version != process.env.VERSION) {
    return c.json({ error: 'Invalid Version' }, 401);
  }

  return next();
});

export const steam_auth = createMiddleware(async (c, next) => {
  const auth_ticket = c.req.header('auth-ticket');

  if (!auth_ticket) {
    return c.json(
      { error: 'Invalid authentication ticket. Restart your game.' },
      401
    );
  }

  const sid = await get_steam_id_from_ticket(auth_ticket);

  if (sid == '') {
    return c.json({ error: 'Invalid Steam Auth Ticket' }, 401);
  }

  c.set('steam_id', sid);

  return next();
});

export const admin_auth = createMiddleware(async (c, next) => {
  const auth_ticket = c.req.header('auth-ticket');

  if (!auth_ticket) {
    return c.json({ error: 'You are not an administrator' }, 401);
  }

  const sid = await get_steam_id_from_ticket(auth_ticket);

  if (sid == '') {
    return c.json({ error: 'Invalid Steam Auth Ticket' }, 401);
  }

  if (!is_admin(sid)) {
    return c.json({ error: 'This user is not an admin.' }, 401);
  }

  return next();
});

export const ban_auth = createMiddleware(async (c, next) => {
  const auth_ticket = c.req.header('auth-ticket');

  if (!auth_ticket) {
    return c.json({ error: 'Invalid auth ticket.' }, 401);
  }

  const sid = await get_steam_id_from_ticket(auth_ticket);

  if (sid == '') {
    return c.json({ error: 'Invalid auth ticket.' }, 401);
  }

  if (await value_banned(sid)) {
    return c.json({ error: 'You are banned from the leaderboard.' }, 401);
  }

  return next();
});
