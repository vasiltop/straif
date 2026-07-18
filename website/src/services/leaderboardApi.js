import { PAGE_SIZE } from '@/data/leaderboards';

const BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? 'https://straifapi.pumped.software';

function endpointFor(query) {
  const params = new URLSearchParams({
    page: String(query.page - 1),
    limit: String(PAGE_SIZE),
  });

  if (query.category === 'aim') {
    return `/leaderboard/aim/scenarios/${query.scenario}/scores?${params}`;
  }

  if (query.category === 'overall') {
    if (query.discipline === 'aim') {
      return `/leaderboard/aim/overall?${params}`;
    }
    const mode = query.discipline === 'target' ? 'target' : 'bhop';
    return `/leaderboard/mode/${mode}/overall?${params}`;
  }

  const mode = query.category === 'target' ? 'target' : 'bhop';
  return `/leaderboard/mode/${mode}/maps/${query.map}/runs?${params}`;
}

function normalizeRows(query, body) {
  if (query.category === 'aim') return body.data.scores;
  if (query.category === 'overall' && query.discipline === 'aim') {
    return body.data.scores;
  }
  if (query.category === 'overall') return body.data;
  return body.data.runs;
}

function normalizeTotal(query, body) {
  if (query.category === 'aim') return body.data.total;
  if (query.category === 'overall' && query.discipline === 'aim') {
    return body.data.total;
  }
  if (query.category === 'overall') return body.total;
  return body.data.total;
}

export async function fetchLeaderboard(
  query,
  { signal, fetchImpl = fetch } = {}
) {
  const response = await fetchImpl(`${BASE_URL}${endpointFor(query)}`, {
    signal,
  });
  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error ?? 'Could not load the leaderboard.');
  }

  const offset = (query.page - 1) * PAGE_SIZE;
  return {
    rows: normalizeRows(query, body).map((row, index) => {
      const rank = row.position ?? offset + index + 1;
      return {
        ...row,
        id: String(rank),
        rank,
      };
    }),
    total: normalizeTotal(query, body),
  };
}
