import {
  describeRoute,
  resolver,
  type DescribeRouteOptions,
} from 'hono-openapi';
import { z } from 'zod';

export function hide_route() {
  return describeRoute({
    hide: true,
  });
}

export function describe_leaderboard_route<T extends z.ZodTypeAny>(
  description: string,
  success_schema: T,
  options: Omit<DescribeRouteOptions, 'description' | 'responses'> = {}
) {
  return describeRoute({
    description,
    tags: ['leaderboard'],
    ...options,
    responses: {
      200: {
        description: 'Successful',
        content: {
          'application/json': {
            schema: resolver(success_schema),
          },
        },
      },
      400: {
        description: 'Error',
        content: {
          'application/json': {
            schema: resolver(
              z.object({
                error: z.string(),
              })
            ),
          },
        },
      },
    },
  });
}
