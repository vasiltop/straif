<script setup>
defineProps({
  categories: { type: Array, required: true },
  modelValue: { type: String, required: true },
});
const emit = defineEmits(['update:modelValue']);
</script>

<template>
  <nav class="leaderboard-tabs" aria-label="Leaderboard categories">
    <button
      v-for="category in categories"
      :key="category.value"
      type="button"
      :data-category="category.value"
      :aria-current="category.value === modelValue ? 'page' : undefined"
      @click="emit('update:modelValue', category.value)"
    >
      {{ category.label }}
    </button>
  </nav>
</template>
