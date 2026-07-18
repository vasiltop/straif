import { describe, expect, it } from 'vitest';
import { createMemoryHistory } from 'vue-router';
import { createStraifRouter } from './index';

describe('Straif router', () => {
  it('defines home and leaderboard routes with document metadata', async () => {
    const router = createStraifRouter(createMemoryHistory());

    await router.push('/leaderboard');
    await router.isReady();

    expect(router.currentRoute.value.name).toBe('leaderboard');
    expect(router.currentRoute.value.meta.title).toBe('Leaderboard — Straif');
    expect(router.getRoutes().map((route) => route.path)).toEqual(
      expect.arrayContaining(['/', '/leaderboard'])
    );
  });

  it('updates document title and description metadata after navigation', async () => {
    document.head.innerHTML = '';

    const router = createStraifRouter(createMemoryHistory());

    await router.push('/leaderboard');
    await router.isReady();

    expect(document.title).toBe('Leaderboard — Straif');
    expect(
      document
        .querySelector('meta[name="description"]')
        ?.getAttribute('content')
    ).toBe('Browse Straif movement, target, aim, and overall leaderboards.');
  });
});
