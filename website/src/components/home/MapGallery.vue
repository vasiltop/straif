<script setup>
import rooftopsImage from '@/assets/maps/map_rooftops.png'
import streetsImage from '@/assets/maps/map_streets.png'
import taurusImage from '@/assets/maps/map_taurus.png'

const maps = [
  { name: 'Streets', modes: 'Movement and target', image: streetsImage },
  { name: 'Taurus', modes: 'Movement', image: taurusImage },
  { name: 'Rooftops', modes: 'Movement and target', image: rooftopsImage },
]
</script>

<template>
  <section class="map-gallery" aria-labelledby="maps-title">
    <header class="section-heading">
      <div>
        <p class="eyebrow">Selected maps</p>
        <h2 id="maps-title">Environments</h2>
      </div>
      <p class="eyebrow">14 maps</p>
    </header>
    <div class="map-list">
      <figure v-for="map in maps" :key="map.name" class="map-feature">
        <img :src="map.image" :alt="`${map.name} map in Straif`" width="1920" height="1080" loading="lazy">
        <figcaption>
          <p class="eyebrow">{{ map.modes }}</p>
          <h3>{{ map.name }}</h3>
          <p>{{ map.modes }} leaderboards are available.</p>
        </figcaption>
      </figure>
    </div>
  </section>
</template>
