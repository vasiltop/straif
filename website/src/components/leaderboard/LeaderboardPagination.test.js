import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import LeaderboardPagination from './LeaderboardPagination.vue'

describe('LeaderboardPagination', () => {
  it('labels navigation and emits the selected page', async () => {
    const wrapper = mount(LeaderboardPagination, {
      props: { page: 2, total: 76, pageSize: 25 },
    })

    expect(wrapper.get('nav').attributes('aria-label')).toBe(
      'Leaderboard pages'
    )
    expect(wrapper.text()).toContain('26–50 of 76')
    await wrapper.get('button[aria-label="Go to page 3"]').trigger('click')
    expect(wrapper.emitted('update:page')).toEqual([[3]])
  })
})
