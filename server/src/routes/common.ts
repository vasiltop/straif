import { describeRoute } from 'hono-openapi';

export function hide_route() {
  return describeRoute({
    hide: true,
  });
}
