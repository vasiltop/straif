export const PAGE_SIZE = 25

export const CATEGORIES = [
  { value: 'movement', label: 'Movement' },
  { value: 'target', label: 'Target' },
  { value: 'aim', label: 'Aim' },
  { value: 'overall', label: 'Overall' },
]

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
].map(([value, label, categories]) => ({ value, label, categories }))

export const AIM_SCENARIOS = [
  { value: 'gridshot', label: 'Gridshot' },
  { value: 'flick', label: 'Flick' },
  { value: 'tracking', label: 'Tracking' },
]

export const OVERALL_DISCIPLINES = [
  { value: 'movement', label: 'Movement' },
  { value: 'target', label: 'Target' },
  { value: 'aim', label: 'Aim' },
]

export function getCategoryMaps(category) {
  return MAPS.filter((map) => map.categories.includes(category))
}

export function normalizeLeaderboardQuery(query = {}) {
  const category = CATEGORIES.some((entry) => entry.value === query.category)
    ? query.category
    : 'movement'
  const page = Math.max(Number.parseInt(query.page, 10) || 1, 1)

  if (category === 'aim') {
    const scenario = AIM_SCENARIOS.some(
      (entry) => entry.value === query.scenario
    )
      ? query.scenario
      : 'gridshot'
    return { category, scenario, page }
  }

  if (category === 'overall') {
    const discipline = OVERALL_DISCIPLINES.some(
      (entry) => entry.value === query.discipline
    )
      ? query.discipline
      : 'movement'
    return { category, discipline, page }
  }

  const maps = getCategoryMaps(category)
  const map = maps.some((entry) => entry.value === query.map)
    ? query.map
    : 'map_rooftops'
  return { category, map, page }
}
