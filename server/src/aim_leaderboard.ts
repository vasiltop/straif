export const AIM_SCENARIOS = ['gridshot', 'flick', 'tracking'] as const;

export type AimScenario = (typeof AIM_SCENARIOS)[number];

export type AimScoreEntry = {
  steam_id: string;
  username: string;
  scenario: AimScenario;
  score: number;
  hits: number;
  misses: number;
  accuracy: number;
  avg_reaction_ms: number;
  created_at: Date;
};

export type AimOverallEntry = {
  steam_id: string;
  username: string;
  total_score: number;
  scenarios_completed: number;
  accuracy: number;
  avg_reaction_ms: number;
};

export function parseAimScenario(value: string): AimScenario | null {
  return AIM_SCENARIOS.includes(value as AimScenario)
    ? (value as AimScenario)
    : null;
}

export function compareAimScoreEntries(
  left: Pick<
    AimScoreEntry,
    'steam_id' | 'score' | 'accuracy' | 'avg_reaction_ms'
  >,
  right: Pick<
    AimScoreEntry,
    'steam_id' | 'score' | 'accuracy' | 'avg_reaction_ms'
  >
) {
  return (
    right.score - left.score ||
    right.accuracy - left.accuracy ||
    left.avg_reaction_ms - right.avg_reaction_ms ||
    left.steam_id.localeCompare(right.steam_id)
  );
}

export function sortAimScoreEntries(entries: AimScoreEntry[]) {
  return [...entries].sort(compareAimScoreEntries);
}

export function compareAimOverallEntries(
  left: AimOverallEntry,
  right: AimOverallEntry
) {
  return (
    right.total_score - left.total_score ||
    right.scenarios_completed - left.scenarios_completed ||
    right.accuracy - left.accuracy ||
    left.avg_reaction_ms - right.avg_reaction_ms ||
    left.steam_id.localeCompare(right.steam_id)
  );
}

export function buildAimOverallLeaderboard(entries: AimScoreEntry[]) {
  const grouped = new Map<
    string,
    AimOverallEntry & {
      accuracy_sum: number;
      reaction_sum: number;
    }
  >();

  for (const entry of entries) {
    const existing = grouped.get(entry.steam_id);

    if (!existing) {
      grouped.set(entry.steam_id, {
        steam_id: entry.steam_id,
        username: entry.username,
        total_score: entry.score,
        scenarios_completed: 1,
        accuracy_sum: entry.accuracy,
        reaction_sum: entry.avg_reaction_ms,
        accuracy: entry.accuracy,
        avg_reaction_ms: entry.avg_reaction_ms,
      });
      continue;
    }

    existing.total_score += entry.score;
    existing.scenarios_completed += 1;
    existing.accuracy_sum += entry.accuracy;
    existing.reaction_sum += entry.avg_reaction_ms;
    existing.username =
      existing.username.localeCompare(entry.username) >= 0
        ? existing.username
        : entry.username;
  }

  return Array.from(grouped.values())
    .map((entry) => ({
      steam_id: entry.steam_id,
      username: entry.username,
      total_score: entry.total_score,
      scenarios_completed: entry.scenarios_completed,
      accuracy: entry.accuracy_sum / entry.scenarios_completed,
      avg_reaction_ms: entry.reaction_sum / entry.scenarios_completed,
    }))
    .sort(compareAimOverallEntries);
}
