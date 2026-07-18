<script setup>
import { computed } from 'vue';

const props = defineProps({
  page: { type: Number, required: true },
  total: { type: Number, required: true },
  pageSize: { type: Number, required: true },
});
const emit = defineEmits(['update:page']);

const totalPages = computed(() =>
  Math.max(Math.ceil(props.total / props.pageSize), 1)
);
const start = computed(() =>
  props.total ? (props.page - 1) * props.pageSize + 1 : 0
);
const end = computed(() => Math.min(props.page * props.pageSize, props.total));
const pages = computed(() => {
  const first = Math.max(1, Math.min(props.page - 2, totalPages.value - 4));
  const last = Math.min(totalPages.value, first + 4);
  return Array.from({ length: last - first + 1 }, (_, index) => first + index);
});
</script>

<template>
  <nav class="pagination" aria-label="Leaderboard pages">
    <p>{{ start }}–{{ end }} of {{ total }}</p>
    <div class="pagination-controls">
      <button
        type="button"
        :disabled="page === 1"
        aria-label="Go to previous page"
        @click="emit('update:page', page - 1)"
      >
        ←
      </button>
      <button
        v-for="pageNumber in pages"
        :key="pageNumber"
        type="button"
        :aria-current="pageNumber === page ? 'page' : undefined"
        :aria-label="`Go to page ${pageNumber}`"
        @click="emit('update:page', pageNumber)"
      >
        {{ pageNumber }}
      </button>
      <button
        type="button"
        :disabled="page === totalPages"
        aria-label="Go to next page"
        @click="emit('update:page', page + 1)"
      >
        →
      </button>
    </div>
  </nav>
</template>
