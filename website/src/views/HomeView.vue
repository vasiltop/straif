<script setup>
import GameIntro from '@/components/home/GameIntro.vue'
import MapGallery from '@/components/home/MapGallery.vue'
import TrailerHero from '@/components/home/TrailerHero.vue'
import LeaderboardPreview from '@/components/leaderboard/LeaderboardPreview.vue'
</script>

<template>
  <main id="main-content">
    <TrailerHero />
    <GameIntro />
    <MapGallery />
    <LeaderboardPreview />
  </main>
</template>
