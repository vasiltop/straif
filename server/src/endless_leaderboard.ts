// Pure, DB-free helpers for the endless (distance/blocks) leaderboard used by
// the procedural map_reverie. Kept standalone so they can be unit tested
// without a database, mirroring aim_leaderboard.ts.
//
// The seed is irrelevant to scoring: the leaderboard simply ranks how many
// blocks players can cover, regardless of which layout they played.

export type EndlessEntry = {
  steam_id: string;
  username: string;
  blocks_reached: number;
  created_at: Date;
};

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

// Keep only each player's best (highest blocks_reached) run.
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
