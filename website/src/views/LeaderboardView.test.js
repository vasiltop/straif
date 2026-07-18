import { mount } from '@vue/test-utils'
import { createMemoryHistory } from 'vue-router'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createStraifRouter } from '@/router'
import { fetchLeaderboard } from '@/services/leaderboardApi'
import LeaderboardView from './LeaderboardView.vue'

vi.mock('@/services/leaderboardApi', () => ({
  fetchLeaderboard: vi.fn(),
}))

describe('LeaderboardView', () => {
  const originalMatchMedia = window.matchMedia
  const originalScrollIntoView = Element.prototype.scrollIntoView

  beforeEach(() => {
    vi.mocked(fetchLeaderboard).mockResolvedValue({
      rows: [
        {
          id: '1',
          rank: 1,
          username: 'Alice',
          time_ms: 18_442,
          created_at: '2026-07-18T11:00:00.000Z',
        },
      ],
      total: 1,
    })

    window.matchMedia = vi.fn().mockReturnValue({
      matches: false,
      media: '(prefers-reduced-motion: reduce)',
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })
    Element.prototype.scrollIntoView = vi.fn()
  })

  afterEach(() => {
    window.matchMedia = originalMatchMedia
    Element.prototype.scrollIntoView = originalScrollIntoView
  })


  it('normalizes incompatible query parameters on mount', async () => {
    const router = createStraifRouter(createMemoryHistory())

    await router.push('/leaderboard?category=target&map=map_taurus&page=0')
    await router.isReady()

    mount(LeaderboardView, {
      global: {
        plugins: [router],
      },
    })

    await vi.waitFor(() => {
      expect(router.currentRoute.value.query).toEqual({
        category: 'target',
        map: 'map_rooftops',
        page: '1',
      })
    })
  })

  it('resets the map and page when switching categories', async () => {
    const router = createStraifRouter(createMemoryHistory())

    await router.push('/leaderboard?category=movement&map=map_taurus&page=3')
    await router.isReady()

    const wrapper = mount(LeaderboardView, {
      global: {
        plugins: [router],
      },
    })

    await wrapper.get('button[data-category="target"]').trigger('click')

    await vi.waitFor(() => {
      expect(router.currentRoute.value.query).toEqual({
        category: 'target',
        map: 'map_rooftops',
        page: '1',
      })
    })
  })
})
