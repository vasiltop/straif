<script setup>
import { computed } from 'vue'
import LeaderboardStatus from './LeaderboardStatus.vue'
import LeaderboardTable from './LeaderboardTable.vue'
import { useLeaderboard } from '@/composables/useLeaderboard'
import { getLeaderboardColumns } from '@/data/leaderboards'

const request = computed(() => ({
  category: 'movement',
  map: 'map_rooftops',
  page: 1,
}))
const { rows, status, error, reload } = useLeaderboard(request)
const columns = getLeaderboardColumns(request.value).filter(
  (column) => column.key !== 'date'
)
const previewRows = computed(() => rows.value.slice(0, 5))
</script>

<template>
  <section class="leaderboard-preview" aria-labelledby="preview-title">
    <header class="section-heading">
      <div>
        <p class="eyebrow">Current records</p>
        <h2 id="preview-title">Rooftops · Bhop</h2>
      </div>
      <RouterLink
        :to="{
          name: 'leaderboard',
          query: { category: 'movement', map: 'map_rooftops', page: '1' },
        }"
      >Full leaderboard</RouterLink>
    </header>
    <LeaderboardStatus v-if="status !== 'success'" :status="status" :error="error" @retry="reload" />
    <LeaderboardTable v-else caption="Rooftops Bhop leaderboard preview" :columns="columns" :rows="previewRows" />
  </section>
</template>
