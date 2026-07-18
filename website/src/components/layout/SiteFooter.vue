<template>
  <footer class="site-footer">
    <p>© {{ new Date().getFullYear() }} Straif</p>
    <nav aria-label="Footer navigation">
      <RouterLink to="/">Home</RouterLink>
      <RouterLink to="/leaderboard">Leaderboard</RouterLink>
      <a href="https://straifapi.pumped.software/docs">API</a>
    </nav>
  </footer>
</template>
