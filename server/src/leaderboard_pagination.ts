import type { DescribeRouteOptions } from 'hono-openapi';
import { z } from 'zod';

type OpenApiParameter = Exclude<
  NonNullable<DescribeRouteOptions['parameters']>[number],
  { $ref: string }
>;

export const LEADERBOARD_DEFAULT_LIMIT = 10;
export const LEADERBOARD_MAX_LIMIT = 100;

export const LeaderboardPaginationQuery = z.object({
  page: z.coerce.number().int().min(0).default(0),
  limit: z.coerce
    .number()
    .int()
    .min(1)
    .max(LEADERBOARD_MAX_LIMIT)
    .default(LEADERBOARD_DEFAULT_LIMIT),
});

export type LeaderboardPagination = z.infer<typeof LeaderboardPaginationQuery>;

export const LeaderboardPaginationParameters = [
  {
    name: 'page',
    in: 'query',
    required: false,
    schema: {
      type: 'integer',
      minimum: 0,
      default: 0,
    },
    description: 'Zero-based leaderboard page number.',
  },
  {
    name: 'limit',
    in: 'query',
    required: false,
    schema: {
      type: 'integer',
      minimum: 1,
      maximum: LEADERBOARD_MAX_LIMIT,
      default: LEADERBOARD_DEFAULT_LIMIT,
    },
    description: 'Rows per page.',
  },
] satisfies OpenApiParameter[];

export function get_leaderboard_offset({ page, limit }: LeaderboardPagination) {
  return page * limit;
}

export function paginate_leaderboard<T>(
  entries: readonly T[],
  pagination: LeaderboardPagination
) {
  const offset = get_leaderboard_offset(pagination);
  return {
    rows: entries.slice(offset, offset + pagination.limit),
    total: entries.length,
  };
}
