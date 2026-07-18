<template>
  <header class="site-header">
    <RouterLink class="wordmark" to="/" aria-label="Straif home"
      >Straif</RouterLink
    >
    <nav aria-label="Primary navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/leaderboard">Leaderboard</RouterLink>
      <a
        class="site-header__cta"
        href="https://store.steampowered.com/app/3850480/Straif/"
        target="_blank"
        rel="noopener noreferrer"
      >
        <svg aria-hidden="true" viewBox="0 0 24 24" focusable="false">
          <circle cx="15.5" cy="8.5" r="4.25" />
          <circle cx="5.75" cy="17.25" r="2.75" />
          <path d="m8.1 15.8 4.4-4.4" />
        </svg>
        Get Straif
      </a>
    </nav>
  </header>
</template>
