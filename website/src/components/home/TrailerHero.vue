<script setup>
import { ref } from 'vue';

const isPlaying = ref(false);
const trailerSrc =
  'https://www.youtube-nocookie.com/embed/CfzotZZ3Sd0?autoplay=1&rel=0';
</script>

<template>
  <section class="trailer-hero" aria-labelledby="trailer-title">
    <div class="trailer-hero__copy">
      <p>Official trailer · YouTube</p>
      <h1 id="trailer-title">Straif</h1>
      <p>Watch film</p>
    </div>

    <div class="trailer-hero__media">
      <template v-if="isPlaying">
        <iframe
          :src="trailerSrc"
          title="Straif official trailer"
          allow="
            accelerometer;
            autoplay;
            clipboard-write;
            encrypted-media;
            gyroscope;
            picture-in-picture;
            web-share;
          "
          allowfullscreen
        />
      </template>
      <template v-else>
        <img
          src="https://i.ytimg.com/vi/CfzotZZ3Sd0/maxresdefault.jpg"
          alt=""
          width="1280"
          height="720"
          fetchpriority="high"
        />
        <button
          type="button"
          aria-label="Play the Straif trailer"
          @click="isPlaying = true"
        >
          Play trailer
        </button>
      </template>
    </div>
  </section>
</template>
