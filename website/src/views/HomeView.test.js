import { mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'
import HomeView from './HomeView.vue'

vi.mock('@/components/leaderboard/LeaderboardPreview.vue', () => ({
  default: { template: '<section aria-label="Leaderboard preview" />' },
}))

describe('HomeView', () => {
  it('uses one main landmark and semantic content sections', () => {
    const wrapper = mount(HomeView, {
      global: {
        stubs: {
          RouterLink: { template: '<a><slot /></a>' },
        },
      },
    })

    expect(wrapper.findAll('main')).toHaveLength(1)
    expect(wrapper.get('h1').text()).toBe('Straif')
    expect(wrapper.get('[aria-labelledby="game-intro-title"]').exists()).toBe(true)
    expect(wrapper.findAll('figure')).toHaveLength(3)
  })
})
