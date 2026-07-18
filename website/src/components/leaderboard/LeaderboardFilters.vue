<script setup>
defineProps({
  category: { type: String, required: true },
  map: { type: String, default: '' },
  scenario: { type: String, default: '' },
  discipline: { type: String, default: '' },
  maps: { type: Array, required: true },
  scenarios: { type: Array, required: true },
  disciplines: { type: Array, required: true },
});
defineEmits(['update:map', 'update:scenario', 'update:discipline']);
</script>

<template>
  <div class="leaderboard-filters">
    <label v-if="category === 'movement' || category === 'target'">
      <span>Map</span>
      <select :value="map" @change="$emit('update:map', $event.target.value)">
        <option
          v-for="option in maps"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </label>
    <label v-else-if="category === 'aim'">
      <span>Scenario</span>
      <select
        :value="scenario"
        @change="$emit('update:scenario', $event.target.value)"
      >
        <option
          v-for="option in scenarios"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </label>
    <label v-else>
      <span>Discipline</span>
      <select
        :value="discipline"
        @change="$emit('update:discipline', $event.target.value)"
      >
        <option
          v-for="option in disciplines"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </label>
  </div>
</template>
