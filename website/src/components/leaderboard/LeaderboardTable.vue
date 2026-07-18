<script setup>
defineProps({
  caption: { type: String, required: true },
  columns: { type: Array, required: true },
  rows: { type: Array, required: true },
})
</script>

<template>
  <div class="table-scroll" tabindex="0" aria-label="Scrollable leaderboard">
    <table class="leaderboard-table">
      <caption>{{ caption }}</caption>
      <thead>
        <tr>
          <th v-for="column in columns" :key="column.key" scope="col">
            {{ column.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id">
          <template v-for="(column, index) in columns" :key="column.key">
            <th v-if="index === 0" scope="row">{{ column.format(row) }}</th>
            <td v-else>{{ column.format(row) }}</td>
          </template>
        </tr>
      </tbody>
    </table>
  </div>
</template>
