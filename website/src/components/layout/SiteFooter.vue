<template>
  <footer class="site-footer">
    <p>© {{ new Date().getFullYear() }} Straif</p>
    <nav aria-label="Footer navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/leaderboard">Leaderboard</RouterLink>
      <a
        href="https://store.steampowered.com/app/3850480/Straif/"
        target="_blank"
        rel="noopener noreferrer"
      >
        Steam
      </a>
      <a
        href="https://straifapi.pumped.software/docs"
        target="_blank"
        rel="noopener noreferrer"
      >
        API
      </a>
    </nav>
  </footer>
</template>
