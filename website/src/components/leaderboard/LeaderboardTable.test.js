import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import LeaderboardTable from './LeaderboardTable.vue'

describe('LeaderboardTable', () => {
  it('renders a caption, scoped headers, and formatted cells', () => {
    const wrapper = mount(LeaderboardTable, {
      props: {
        caption: 'Rooftops Bhop leaderboard',
        columns: [
          { key: 'rank', label: 'Rank', format: (row) => row.rank },
          { key: 'username', label: 'Player', format: (row) => row.username },
          { key: 'time', label: 'Time', format: (row) => `${row.time_ms}ms` },
        ],
        rows: [{ id: '1', rank: 1, username: 'Alice', time_ms: 18442 }],
      },
    })

    expect(wrapper.get('caption').text()).toBe('Rooftops Bhop leaderboard')
    expect(wrapper.findAll('th[scope="col"]')).toHaveLength(3)
    expect(wrapper.get('tbody th[scope="row"]').text()).toBe('1')
    expect(wrapper.text()).toContain('Alice')
  })
})
