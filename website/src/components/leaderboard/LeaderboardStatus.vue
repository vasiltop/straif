<script setup>
defineProps({
  status: { type: String, required: true },
  error: { type: String, default: '' },
});
defineEmits(['retry']);
</script>

<template>
  <div class="leaderboard-status" aria-live="polite">
    <p v-if="status === 'loading'">Loading leaderboard…</p>
    <p v-else-if="status === 'empty'">No records exist for this selection.</p>
    <div v-else-if="status === 'error'">
      <p>{{ error }}</p>
      <button type="button" @click="$emit('retry')">Try again</button>
    </div>
  </div>
</template>
