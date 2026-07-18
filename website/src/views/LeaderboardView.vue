<script setup>
import { computed, nextTick, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import LeaderboardCategoryTabs from '@/components/leaderboard/LeaderboardCategoryTabs.vue'
import LeaderboardFilters from '@/components/leaderboard/LeaderboardFilters.vue'
import LeaderboardPagination from '@/components/leaderboard/LeaderboardPagination.vue'
import LeaderboardStatus from '@/components/leaderboard/LeaderboardStatus.vue'
import LeaderboardTable from '@/components/leaderboard/LeaderboardTable.vue'
import { useLeaderboard } from '@/composables/useLeaderboard'
import {
  AIM_SCENARIOS,
  CATEGORIES,
  OVERALL_DISCIPLINES,
  PAGE_SIZE,
  getCategoryMaps,
  getLeaderboardColumns,
  normalizeLeaderboardQuery,
} from '@/data/leaderboards'

const route = useRoute()
const router = useRouter()
const resultsHeading = ref(null)

function stringifyQuery(query) {
  return Object.fromEntries(
    Object.entries(query).map(([key, value]) => [key, String(value)])
  )
}

function serializeQuery(query) {
  return JSON.stringify(
    Object.entries(stringifyQuery(query)).sort(([left], [right]) =>
      left.localeCompare(right)
    )
  )
}

function getLabel(options, value, fallback) {
  return options.find((option) => option.value === value)?.label ?? fallback
}

const normalized = computed(() => normalizeLeaderboardQuery(route.query))
const serialized = computed(() => serializeQuery(normalized.value))

watch(
  serialized,
  () => {
    if (serializeQuery(route.query) === serialized.value) return
    router.replace({ name: 'leaderboard', query: stringifyQuery(normalized.value) })
  },
  { immediate: true }
)

const maps = computed(() => getCategoryMaps(normalized.value.category))
const columns = computed(() => getLeaderboardColumns(normalized.value))
const boardTitle = computed(() => {
  if (normalized.value.category === 'aim') {
    return getLabel(AIM_SCENARIOS, normalized.value.scenario, 'Gridshot')
  }

  if (normalized.value.category === 'overall') {
    return getLabel(
      OVERALL_DISCIPLINES,
      normalized.value.discipline,
      'Movement'
    )
  }

  return getLabel(maps.value, normalized.value.map, 'Rooftops')
})
const caption = computed(() => `${boardTitle.value} leaderboard`)
const { rows, total, status, error, reload } = useLeaderboard(normalized)

async function setQuery(patch, resetPage = false) {
  const nextQuery = normalizeLeaderboardQuery({
    ...normalized.value,
    ...patch,
    page: resetPage ? 1 : patch.page ?? normalized.value.page,
  })

  await router.push({ name: 'leaderboard', query: stringifyQuery(nextQuery) })
}

async function setPage(page) {
  await setQuery({ page })
  await nextTick()

  const heading = resultsHeading.value

  if (!heading) return

  heading.focus()
  const prefersReducedMotion =
    window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches ?? false

  heading.scrollIntoView?.({
    behavior: prefersReducedMotion ? 'auto' : 'smooth',
    block: 'start',
  })
}
</script>

<template>
  <main id="main-content" class="leaderboard-page">
    <header class="page-heading">
      <p class="eyebrow">Global records</p>
      <h1>Leaderboard</h1>
      <p>Movement, target, aim, and overall rankings.</p>
    </header>
    <LeaderboardCategoryTabs
      :categories="CATEGORIES"
      :model-value="normalized.category"
      @update:model-value="setQuery({ category: $event }, true)"
    />
    <LeaderboardFilters
      :category="normalized.category"
      :map="normalized.map"
      :scenario="normalized.scenario"
      :discipline="normalized.discipline"
      :maps="maps"
      :scenarios="AIM_SCENARIOS"
      :disciplines="OVERALL_DISCIPLINES"
      @update:map="setQuery({ map: $event }, true)"
      @update:scenario="setQuery({ scenario: $event }, true)"
      @update:discipline="setQuery({ discipline: $event }, true)"
    />
    <section class="leaderboard-results" aria-labelledby="results-title">
      <div class="section-heading">
        <h2 id="results-title" ref="resultsHeading" tabindex="-1">{{ boardTitle }}</h2>
        <p>{{ total }} entries</p>
      </div>
      <LeaderboardStatus v-if="status !== 'success'" :status="status" :error="error" @retry="reload" />
      <template v-else>
        <LeaderboardTable :caption="caption" :columns="columns" :rows="rows" />
        <LeaderboardPagination :page="normalized.page" :total="total" :page-size="PAGE_SIZE" @update:page="setPage" />
      </template>
    </section>
  </main>
</template>
