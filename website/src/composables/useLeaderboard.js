import { onScopeDispose, ref, watch } from 'vue';
import { fetchLeaderboard } from '@/services/leaderboardApi';

export function useLeaderboard(request, loader = fetchLeaderboard) {
  const rows = ref([]);
  const total = ref(0);
  const status = ref('loading');
  const error = ref('');
  let controller;

  async function load() {
    controller?.abort();
    const activeController = new AbortController();
    controller = activeController;
    status.value = 'loading';
    error.value = '';

    try {
      const result = await loader(request.value, {
        signal: activeController.signal,
      });

      if (activeController !== controller || activeController.signal.aborted) {
        return;
      }

      rows.value = result.rows;
      total.value = result.total;
      status.value = result.rows.length === 0 ? 'empty' : 'success';
    } catch (cause) {
      if (cause?.name === 'AbortError' || activeController.signal.aborted) {
        return;
      }

      rows.value = [];
      total.value = 0;
      error.value =
        cause instanceof Error
          ? cause.message
          : 'Could not load the leaderboard.';
      status.value = 'error';
    }
  }

  watch(request, load, { deep: true, immediate: true });
  onScopeDispose(() => controller?.abort());

  return { rows, total, status, error, reload: load };
}
