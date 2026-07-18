import { computed, effectScope, nextTick, ref } from 'vue';
import { describe, expect, it, vi } from 'vitest';
import { useLeaderboard } from './useLeaderboard';

describe('useLeaderboard', () => {
  it('loads rows and exposes success state', async () => {
    const request = ref({ category: 'movement', map: 'map_rooftops', page: 1 });
    const loader = vi.fn().mockResolvedValue({ rows: [{ id: '1' }], total: 1 });
    const scope = effectScope();
    const state = scope.run(() =>
      useLeaderboard(
        computed(() => request.value),
        loader
      )
    );

    await vi.waitFor(() => expect(state.status.value).toBe('success'));
    expect(state.rows.value).toEqual([{ id: '1' }]);
    scope.stop();
  });

  it('aborts the stale request when filters change', async () => {
    const request = ref({ category: 'movement', map: 'map_rooftops', page: 1 });
    const signals = [];
    const loader = vi.fn((_query, { signal }) => {
      signals.push(signal);
      return new Promise(() => {});
    });
    const scope = effectScope();
    scope.run(() =>
      useLeaderboard(
        computed(() => request.value),
        loader
      )
    );

    request.value = { category: 'movement', map: 'map_streets', page: 1 };
    await nextTick();

    expect(signals[0].aborted).toBe(true);
    scope.stop();
  });
});
