import {
  formatDate,
  formatInteger,
  formatPercentage,
  formatReaction,
  formatTime,
} from '@/utils/formatters';

export const PAGE_SIZE = 25;

export const CATEGORIES = [
  { value: 'movement', label: 'Movement' },
  { value: 'target', label: 'Target' },
  { value: 'aim', label: 'Aim' },
  { value: 'overall', label: 'Overall' },
];

export const MAPS = [
  ['Tutorial', 'Tutorial', ['movement', 'target']],
  ['map_rooftops', 'Rooftops', ['movement', 'target']],
  ['map_streets', 'Streets', ['movement', 'target']],
  ['map_flow', 'Flow', ['movement', 'target']],
  ['map_line', 'Line', ['movement']],
  ['map_rookie', 'Rookie', ['movement']],
  ['map_dawn', 'Dawn', ['movement']],
  ['map_structure', 'Structure', ['movement', 'target']],
  ['map_graybox', 'Graybox', ['movement', 'target']],
  ['map_graybox2', 'Graybox 2', ['movement', 'target']],
  ['map_subway', 'Subway', ['movement', 'target']],
  ['map_rooftops2', 'Rooftops 2', ['movement', 'target']],
  ['map_slope', 'Slope', ['movement']],
  ['map_taurus', 'Taurus', ['movement']],
].map(([value, label, categories]) => ({ value, label, categories }));

export const AIM_SCENARIOS = [
  { value: 'gridshot', label: 'Gridshot' },
  { value: 'flick', label: 'Flick' },
  { value: 'tracking', label: 'Tracking' },
];

export const OVERALL_DISCIPLINES = [
  { value: 'movement', label: 'Movement' },
  { value: 'target', label: 'Target' },
  { value: 'aim', label: 'Aim' },
];

const rankColumn = {
  key: 'rank',
  label: 'Rank',
  format: (row) => row.rank,
};

const playerColumn = {
  key: 'player',
  label: 'Player',
  format: (row) => row.username,
};

export function getCategoryMaps(category) {
  return MAPS.filter((map) => map.categories.includes(category));
}

export function getLeaderboardColumns(query) {
  if (query.category === 'aim') {
    return [
      rankColumn,
      playerColumn,
      {
        key: 'score',
        label: 'Score',
        format: (row) => formatInteger(row.score),
      },
      {
        key: 'accuracy',
        label: 'Accuracy',
        format: (row) => formatPercentage(row.accuracy),
      },
      {
        key: 'reaction',
        label: 'Reaction',
        format: (row) => formatReaction(row.avg_reaction_ms),
      },
      {
        key: 'date',
        label: 'Date',
        format: (row) => formatDate(row.created_at),
      },
    ];
  }

  if (query.category === 'overall' && query.discipline === 'aim') {
    return [
      rankColumn,
      playerColumn,
      {
        key: 'total-score',
        label: 'Total score',
        format: (row) => formatInteger(row.total_score),
      },
      {
        key: 'scenarios',
        label: 'Scenarios',
        format: (row) => formatInteger(row.scenarios_completed),
      },
      {
        key: 'accuracy',
        label: 'Accuracy',
        format: (row) => formatPercentage(row.accuracy),
      },
      {
        key: 'reaction',
        label: 'Reaction',
        format: (row) => formatReaction(row.avg_reaction_ms),
      },
    ];
  }

  if (query.category === 'overall') {
    return [
      rankColumn,
      playerColumn,
      {
        key: 'points',
        label: 'Points',
        format: (row) => formatInteger(row.points),
      },
    ];
  }

  return [
    rankColumn,
    playerColumn,
    {
      key: 'time',
      label: 'Time',
      format: (row) => formatTime(row.time_ms),
    },
    {
      key: 'date',
      label: 'Date',
      format: (row) => formatDate(row.created_at),
    },
  ];
}

export function normalizeLeaderboardQuery(query = {}) {
  const category = CATEGORIES.some((entry) => entry.value === query.category)
    ? query.category
    : 'movement';
  const page = Math.max(Number.parseInt(query.page, 10) || 1, 1);

  if (category === 'aim') {
    const scenario = AIM_SCENARIOS.some(
      (entry) => entry.value === query.scenario
    )
      ? query.scenario
      : 'gridshot';
    return { category, scenario, page };
  }

  if (category === 'overall') {
    const discipline = OVERALL_DISCIPLINES.some(
      (entry) => entry.value === query.discipline
    )
      ? query.discipline
      : 'movement';
    return { category, discipline, page };
  }

  const maps = getCategoryMaps(category);
  const map = maps.some((entry) => entry.value === query.map)
    ? query.map
    : 'map_rooftops';
  return { category, map, page };
}
