// Pure, DB-free helpers for the endless (distance/blocks) seed leaderboard used
// by the procedural map_reverie. Kept standalone so they can be unit tested
// without a database, mirroring aim_leaderboard.ts.

export type EndlessEntry = {
  steam_id: string;
  username: string;
  seed: string;
  blocks_reached: number;
  created_at: Date;
};

// Validate a seed that arrives as a string. Seeds are 64-bit integers sent as
// strings to avoid JSON float precision loss. Returns the normalized string or
// null when it is not a valid integer.
export function parseSeed(value: string): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!/^-?\d+$/.test(trimmed)) return null;
  try {
    return BigInt(trimmed).toString();
  } catch {
    return null;
  }
}

// Leaderboard ordering: most blocks first, then a deterministic tiebreak on the
// steam id so pagination is stable.
export function compareEndlessEntries(
  left: Pick<EndlessEntry, 'steam_id' | 'blocks_reached'>,
  right: Pick<EndlessEntry, 'steam_id' | 'blocks_reached'>
) {
  return (
    right.blocks_reached - left.blocks_reached ||
    left.steam_id.localeCompare(right.steam_id)
  );
}

export function sortEndlessEntries(entries: EndlessEntry[]) {
  return [...entries].sort(compareEndlessEntries);
}

// Keep only each player's best (highest blocks_reached) run, carrying the seed
// of that best run so it can be replayed from the leaderboard.
export function bestPerPlayer(entries: EndlessEntry[]) {
  const best = new Map<string, EndlessEntry>();
  for (const entry of entries) {
    const existing = best.get(entry.steam_id);
    if (!existing || entry.blocks_reached > existing.blocks_reached) {
      best.set(entry.steam_id, entry);
    }
  }
  return sortEndlessEntries(Array.from(best.values()));
}
