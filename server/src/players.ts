import { admins } from './db/schema';
import db from './db/index';
import { eq } from 'drizzle-orm';

export async function is_admin(steam_id: string): Promise<boolean> {
  console.log(steam_id);
  const res = await db
    .select()
    .from(admins)
    .where(eq(admins.steam_id, steam_id));

  return res.length != 0;
}
