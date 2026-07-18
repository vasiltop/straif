import { describe, expect, it } from 'vitest';
import {
  formatDate,
  formatInteger,
  formatPercentage,
  formatReaction,
  formatTime,
} from './formatters';

describe('leaderboard formatters', () => {
  it('formats leaderboard metrics consistently', () => {
    expect(formatTime(18_442)).toBe('18.442s');
    expect(formatInteger(84220)).toBe('84,220');
    expect(formatPercentage(92.456)).toBe('92.46%');
    expect(formatReaction(243.6)).toBe('244ms');
    expect(formatDate('2026-07-18T11:00:00.000Z')).toBe('2026.07.18');
  });
});
