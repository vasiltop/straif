import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/HomeView.vue'),
    meta: {
      title: 'Straif',
      description:
        'Straif is a fast-paced 3D platforming shooter built around movement and global leaderboards.',
    },
  },
  {
    path: '/leaderboard',
    name: 'leaderboard',
    component: () => import('@/views/LeaderboardView.vue'),
    meta: {
      title: 'Leaderboard — Straif',
      description:
        'Browse Straif movement, target, aim, and overall leaderboards.',
    },
  },
];

function getDescriptionMetaTag() {
  let metaDescription = document.querySelector('meta[name="description"]');

  if (!metaDescription) {
    metaDescription = document.createElement('meta');
    metaDescription.setAttribute('name', 'description');
    document.head.appendChild(metaDescription);
  }

  return metaDescription;
}

export function createStraifRouter(history = createWebHistory()) {
  const router = createRouter({ history, routes });

  router.afterEach((to) => {
    document.title = to.meta.title;
    getDescriptionMetaTag().setAttribute('content', to.meta.description);
  });

  return router;
}
