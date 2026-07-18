import assert from 'node:assert/strict';
import test from 'node:test';
import { Hono } from 'hono';
import { createAdminAuth, type AdminAuthDependencies } from './middleware';

type TestVariables = {
  steam_id: string;
};

function build_app(deps: AdminAuthDependencies) {
  const handler_calls: string[] = [];
  const app = new Hono<{ Variables: TestVariables }>();

  app.use('/admin', createAdminAuth(deps));
  app.get('/admin', (c) => {
    handler_calls.push(c.get('steam_id'));
    return c.json({ ok: true, steam_id: c.get('steam_id') });
  });

  return { app, handler_calls };
}

void test('rejects a request missing the auth ticket header', async () => {
  const authenticate_calls: string[] = [];
  const is_admin_calls: string[] = [];
  const { app, handler_calls } = build_app({
    authenticateTicket: async (ticket) => {
      authenticate_calls.push(ticket);
      return 'some-steam-id';
    },
    isAdmin: async (steam_id) => {
      is_admin_calls.push(steam_id);
      return true;
    },
  });

  const res = await app.request('/admin');

  assert.equal(res.status, 401);
  assert.deepEqual(await res.json(), {
    error: 'You are not an administrator',
  });
  assert.deepEqual(authenticate_calls, []);
  assert.deepEqual(is_admin_calls, []);
  assert.deepEqual(handler_calls, []);
});

void test('rejects a request with an invalid auth ticket', async () => {
  const is_admin_calls: string[] = [];
  const { app, handler_calls } = build_app({
    authenticateTicket: async () => '',
    isAdmin: async (steam_id) => {
      is_admin_calls.push(steam_id);
      return true;
    },
  });

  const res = await app.request('/admin', {
    headers: { 'auth-ticket': 'bogus-ticket' },
  });

  assert.equal(res.status, 401);
  assert.deepEqual(await res.json(), { error: 'Invalid Steam Auth Ticket' });
  assert.deepEqual(is_admin_calls, []);
  assert.deepEqual(handler_calls, []);
});

void test('rejects an authenticated non-admin user only after awaiting isAdmin', async () => {
  let is_admin_resolved = false;
  const { app, handler_calls } = build_app({
    authenticateTicket: async () => 'non-admin-steam-id',
    isAdmin: async (steam_id) => {
      assert.equal(steam_id, 'non-admin-steam-id');
      await new Promise((resolve) => setTimeout(resolve, 5));
      is_admin_resolved = true;
      return false;
    },
  });

  const res = await app.request('/admin', {
    headers: { 'auth-ticket': 'valid-ticket' },
  });

  assert.equal(is_admin_resolved, true);
  assert.equal(res.status, 401);
  assert.deepEqual(await res.json(), {
    error: 'This user is not an admin.',
  });
  assert.deepEqual(handler_calls, []);
});

void test('passes through and sets steam_id for an authorized admin', async () => {
  const { app, handler_calls } = build_app({
    authenticateTicket: async () => 'admin-steam-id',
    isAdmin: async () => true,
  });

  const res = await app.request('/admin', {
    headers: { 'auth-ticket': 'valid-ticket' },
  });

  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    ok: true,
    steam_id: 'admin-steam-id',
  });
  assert.deepEqual(handler_calls, ['admin-steam-id']);
});
