<script setup>
import SiteFooter from '@/components/layout/SiteFooter.vue';
import SiteHeader from '@/components/layout/SiteHeader.vue';
</script>

<template>
  <a class="skip-link" href="#main-content">Skip to content</a>
  <SiteHeader />
  <RouterView />
  <SiteFooter />
</template>
