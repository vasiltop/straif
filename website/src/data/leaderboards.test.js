import { describe, expect, it } from 'vitest'
import {
  getCategoryMaps,
  normalizeLeaderboardQuery,
} from './leaderboards'

describe('leaderboard metadata', () => {
  it('excludes bhop-only maps from Target', () => {
    expect(getCategoryMaps('target').map((map) => map.value)).not.toContain(
      'map_taurus'
    )
    expect(getCategoryMaps('movement').map((map) => map.value)).toContain(
      'map_taurus'
    )
  })

  it('normalizes incompatible route values', () => {
    expect(
      normalizeLeaderboardQuery({
        category: 'aim',
        scenario: 'unknown',
        page: '-4',
      })
    ).toEqual({
      category: 'aim',
      scenario: 'gridshot',
      page: 1,
    })
  })
})
