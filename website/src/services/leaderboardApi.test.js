import { describe, expect, it, vi } from 'vitest';
import { fetchLeaderboard } from './leaderboardApi';

function response(body, ok = true) {
  return { ok, json: vi.fn().mockResolvedValue(body) };
}

describe('fetchLeaderboard', () => {
  it('requests a 25-row Movement page and normalizes ranks', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      response({
        data: {
          runs: [
            {
              steam_id: '1',
              username: 'Alice',
              time_ms: 18442,
              created_at: '2026-07-18',
            },
            {
              steam_id: '1',
              username: 'Alice',
              time_ms: 18510,
              created_at: '2026-07-18',
            },
          ],
          total: 26,
        },
      })
    );

    const result = await fetchLeaderboard(
      { category: 'movement', map: 'map_rooftops', page: 2 },
      { fetchImpl }
    );

    expect(fetchImpl).toHaveBeenCalledWith(
      expect.stringContaining(
        '/leaderboard/mode/bhop/maps/map_rooftops/runs?page=1&limit=25'
      ),
      expect.objectContaining({ signal: undefined })
    );
    expect(result.rows[0]).toMatchObject({
      id: '26',
      rank: 26,
      username: 'Alice',
      time_ms: 18442,
    });
    expect(result.rows.map((row) => row.id)).toEqual(['26', '27']);
    expect(result.total).toBe(26);
  });

  it('normalizes overall Aim scores', async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      response({
        data: {
          scores: [
            {
              steam_id: '2',
              username: 'Bob',
              total_score: 84220,
              scenarios_completed: 3,
              accuracy: 92.4,
              avg_reaction_ms: 240,
            },
          ],
          total: 1,
        },
      })
    );

    const result = await fetchLeaderboard(
      { category: 'overall', discipline: 'aim', page: 1 },
      { fetchImpl }
    );

    expect(result.rows[0].total_score).toBe(84220);
    expect(result.total).toBe(1);
  });

  it('throws the API message for failed requests', async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValue(
        response({ error: 'Leaderboard unavailable.' }, false)
      );

    await expect(
      fetchLeaderboard(
        { category: 'aim', scenario: 'gridshot', page: 1 },
        { fetchImpl }
      )
    ).rejects.toThrow('Leaderboard unavailable.');
  });
});
