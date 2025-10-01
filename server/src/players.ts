import { admins, banned_values } from './db/schema';
import db from './db/index';
import { eq } from 'drizzle-orm';

export async function is_admin(steam_id: string): Promise<boolean> {
  const res = await db
    .select()
    .from(admins)
    .where(eq(admins.steam_id, steam_id));

  return res.length != 0;
}

export async function value_banned(value: string) {
  const res = await db
    .select()
    .from(banned_values)
    .where(eq(banned_values.value, value));

  return res.length != 0;
}
