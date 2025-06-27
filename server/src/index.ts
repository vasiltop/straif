import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import leaderboard from './routes/leaderboard.ts'

const app = new Hono()

app.route('/leaderboard', leaderboard);

serve({
  fetch: app.fetch,
  port: 3000
}, (info) => {
  console.log(`Server is running on http://localhost:${info.port}`)
})
