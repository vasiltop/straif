import { Hono } from 'hono';
import db from '../db/index';
import { aim_scores } from '../db/schema';
import { and, asc, desc, eq, gt, lt, or, sql } from 'drizzle-orm';
import { version_compare, steam_auth, ban_auth } from '../middleware';
import { z } from 'zod';
import {
  describeRoute,
  resolver,
  validator as zValidator,
  type DescribeRouteOptions,
} from 'hono-openapi';
import { type Variables } from '../index';
import { hide_route } from './common';
import {
  AIM_SCENARIOS,
  parseAimScenario,
  type AimScenario,
} from '../aim_leaderboard';
import {
  get_leaderboard_offset,
  LeaderboardPaginationParameters,
  LeaderboardPaginationQuery,
} from '../leaderboard_pagination';

const app = new Hono<{ Variables: Variables }>();

type OpenApiParameter = Exclude<
  NonNullable<DescribeRouteOptions['parameters']>[number],
  { $ref: string }
>;

type OpenApiRequestBody = Exclude<
  NonNullable<DescribeRouteOptions['requestBody']>,
  { $ref: string }
>;

const ScenarioParamInput = z.object({
  scenario: z.string(),
});

const AimScoreInput = z.object({
  score: z.number().int().min(0),
  hits: z.number().int().min(0),
  misses: z.number().int().min(0),
  accuracy: z.number().min(0).max(100),
  avg_reaction_ms: z.number().int().min(0),
  username: z.string().trim().min(1).max(64),
});

const ScenarioPathParameter = {
  name: 'scenario',
  in: 'path',
  required: true,
  schema: {
    type: 'string',
    enum: [...AIM_SCENARIOS],
  },
  description: 'The aim scenario to operate on.',
} satisfies OpenApiParameter;

const AimScoreRequestBody = {
  required: true,
  content: {
    'application/json': {
      schema: {
        type: 'object',
        required: [
          'score',
          'hits',
          'misses',
          'accuracy',
          'avg_reaction_ms',
          'username',
        ],
        properties: {
          score: {
            type: 'integer',
            minimum: 0,
          },
          hits: {
            type: 'integer',
            minimum: 0,
          },
          misses: {
            type: 'integer',
            minimum: 0,
          },
          accuracy: {
            type: 'number',
            minimum: 0,
            maximum: 100,
          },
          avg_reaction_ms: {
            type: 'integer',
            minimum: 0,
          },
          username: {
            type: 'string',
            minLength: 1,
            maxLength: 64,
          },
        },
      },
    },
  },
} satisfies OpenApiRequestBody;

const AimScoreSubmissionResponse = z.object({
  data: z.object({
    message: z.string(),
    personal_best: z.boolean(),
    score: z.number(),
    position: z.number().int().min(1),
  }),
});

const AimScenarioScore = z.object({
  steam_id: z.string(),
  username: z.string(),
  score: z.number(),
  hits: z.number(),
  misses: z.number(),
  accuracy: z.number(),
  avg_reaction_ms: z.number(),
  created_at: z.string(),
  position: z.number().int().min(1),
});

const AimScenarioLeaderboardResponse = z.object({
  data: z.object({
    scores: z.array(AimScenarioScore),
    total: z.number().int().min(0),
  }),
});

const AimOverallScore = z.object({
  steam_id: z.string(),
  username: z.string(),
  total_score: z.number().int().min(0),
  scenarios_completed: z.number().int().min(1),
  accuracy: z.number(),
  avg_reaction_ms: z.number(),
});

const AimOverallLeaderboardResponse = z.object({
  data: z.object({
    scores: z.array(AimOverallScore),
  }),
});

const CountAll = sql<number>`count(*)`.mapWith(Number);
const TotalScoreExpression = sql`sum(${aim_scores.score})`;
const TotalScore = TotalScoreExpression.mapWith(Number).as('total_score');
const ScenariosCompletedExpression = sql`count(*)`;
const ScenariosCompleted = ScenariosCompletedExpression.mapWith(Number).as(
  'scenarios_completed'
);
const AccuracyAverageExpression = sql`avg(${aim_scores.accuracy})`;
const AccuracyAverage =
  AccuracyAverageExpression.mapWith(Number).as('accuracy');
const AvgReactionExpression = sql`avg(${aim_scores.avg_reaction_ms})`;
const AvgReaction = AvgReactionExpression.mapWith(Number).as('avg_reaction_ms');
const DeterministicUsername =
  sql<string>`coalesce(max(${aim_scores.username}), '')`.as('username');

function describe_aim_route<T extends z.ZodTypeAny>(
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

function formatAimScoreRow(
  score: Pick<
    typeof aim_scores.$inferSelect,
    | 'steam_id'
    | 'username'
    | 'score'
    | 'hits'
    | 'misses'
    | 'accuracy'
    | 'avg_reaction_ms'
    | 'created_at'
  >,
  position: number
) {
  return {
    steam_id: score.steam_id,
    username: score.username,
    score: score.score,
    hits: score.hits,
    misses: score.misses,
    accuracy: score.accuracy,
    avg_reaction_ms: score.avg_reaction_ms,
    created_at: score.created_at.toISOString(),
    position,
  };
}

function getValidatedScenario(rawScenario: string): AimScenario | null {
  return parseAimScenario(rawScenario);
}

function getRowsAheadCondition(
  scenario: AimScenario,
  row: Pick<
    typeof aim_scores.$inferSelect,
    'steam_id' | 'score' | 'accuracy' | 'avg_reaction_ms'
  >
) {
  return and(
    eq(aim_scores.scenario, scenario),
    or(
      gt(aim_scores.score, row.score),
      and(
        eq(aim_scores.score, row.score),
        gt(aim_scores.accuracy, row.accuracy)
      ),
      and(
        eq(aim_scores.score, row.score),
        eq(aim_scores.accuracy, row.accuracy),
        lt(aim_scores.avg_reaction_ms, row.avg_reaction_ms)
      ),
      and(
        eq(aim_scores.score, row.score),
        eq(aim_scores.accuracy, row.accuracy),
        eq(aim_scores.avg_reaction_ms, row.avg_reaction_ms),
        lt(aim_scores.steam_id, row.steam_id)
      )
    )
  );
}

app.post(
  '/scenarios/:scenario/scores',
  describe_aim_route(
    'Submits a player score for a specific aim scenario and updates that scenario personal best only when the new score is strictly higher.',
    AimScoreSubmissionResponse,
    {
      parameters: [ScenarioPathParameter],
      requestBody: AimScoreRequestBody,
    }
  ),
  zValidator('param', ScenarioParamInput),
  zValidator('json', AimScoreInput),
  hide_route(),
  steam_auth,
  ban_auth,
  version_compare,
  async (c) => {
    const parsedScenario = getValidatedScenario(c.req.valid('param').scenario);
    if (!parsedScenario) {
      return c.json({ error: 'Invalid aim scenario.' }, 400);
    }

    const body = c.req.valid('json');
    const steam_id = c.get('steam_id');

    try {
      const result = await db.transaction(async (tx) => {
        const persistedRows = await tx
          .insert(aim_scores)
          .values({
            steam_id,
            username: body.username,
            scenario: parsedScenario,
            score: body.score,
            hits: body.hits,
            misses: body.misses,
            accuracy: body.accuracy,
            avg_reaction_ms: body.avg_reaction_ms,
            created_at: new Date(),
          })
          .onConflictDoUpdate({
            target: [aim_scores.steam_id, aim_scores.scenario],
            set: {
              username: body.username,
              score: body.score,
              hits: body.hits,
              misses: body.misses,
              accuracy: body.accuracy,
              avg_reaction_ms: body.avg_reaction_ms,
              created_at: new Date(),
            },
            setWhere: sql`${aim_scores.score} < ${body.score}`,
          })
          .returning({
            steam_id: aim_scores.steam_id,
          });

        const storedRows = await tx
          .select({
            steam_id: aim_scores.steam_id,
            score: aim_scores.score,
            accuracy: aim_scores.accuracy,
            avg_reaction_ms: aim_scores.avg_reaction_ms,
          })
          .from(aim_scores)
          .where(
            and(
              eq(aim_scores.steam_id, steam_id),
              eq(aim_scores.scenario, parsedScenario)
            )
          )
          .limit(1);

        const storedScore = storedRows[0];
        if (!storedScore) {
          throw new Error('Could not find stored aim score.');
        }

        const aheadRows = await tx
          .select({
            count: CountAll,
          })
          .from(aim_scores)
          .where(getRowsAheadCondition(parsedScenario, storedScore));

        return {
          message:
            persistedRows.length > 0
              ? 'New personal best saved.'
              : 'Score did not beat your personal best.',
          personal_best: persistedRows.length > 0,
          score: storedScore.score,
          position: aheadRows[0].count + 1,
        };
      });

      return c.json({
        data: result,
      });
    } catch (e) {
      console.log(e);
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

app.get(
  '/scenarios/:scenario/scores',
  describe_aim_route(
    'Fetches a paginated leaderboard for a single aim scenario ordered by score descending, then accuracy descending, then average reaction time ascending.',
    AimScenarioLeaderboardResponse,
    {
      parameters: [ScenarioPathParameter, ...LeaderboardPaginationParameters],
    }
  ),
  zValidator('param', ScenarioParamInput),
  zValidator('query', LeaderboardPaginationQuery),
  async (c) => {
    const parsedScenario = getValidatedScenario(c.req.valid('param').scenario);
    if (!parsedScenario) {
      return c.json({ error: 'Invalid aim scenario.' }, 400);
    }

    const pagination = c.req.valid('query');

    try {
      const [scores, totalRows] = await Promise.all([
        db
          .select({
            steam_id: aim_scores.steam_id,
            username: aim_scores.username,
            score: aim_scores.score,
            hits: aim_scores.hits,
            misses: aim_scores.misses,
            accuracy: aim_scores.accuracy,
            avg_reaction_ms: aim_scores.avg_reaction_ms,
            created_at: aim_scores.created_at,
          })
          .from(aim_scores)
          .where(eq(aim_scores.scenario, parsedScenario))
          .orderBy(
            desc(aim_scores.score),
            desc(aim_scores.accuracy),
            asc(aim_scores.avg_reaction_ms),
            asc(aim_scores.steam_id)
          )
          .limit(pagination.limit)
          .offset(get_leaderboard_offset(pagination)),
        db
          .select({
            count: CountAll,
          })
          .from(aim_scores)
          .where(eq(aim_scores.scenario, parsedScenario)),
      ]);

      return c.json({
        data: {
          scores: scores.map((score, index) =>
            formatAimScoreRow(
              score,
              get_leaderboard_offset(pagination) + index + 1
            )
          ),
          total: totalRows[0].count,
        },
      });
    } catch (e) {
      console.log(e);
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

app.get(
  '/overall',
  describe_aim_route(
    'Fetches the overall aim leaderboard by aggregating each player’s best score from every completed scenario.',
    AimOverallLeaderboardResponse
  ),
  async (c) => {
    try {
      const scores = await db
        .select({
          steam_id: aim_scores.steam_id,
          username: DeterministicUsername,
          total_score: TotalScore,
          scenarios_completed: ScenariosCompleted,
          accuracy: AccuracyAverage,
          avg_reaction_ms: AvgReaction,
        })
        .from(aim_scores)
        .groupBy(aim_scores.steam_id)
        .orderBy(
          desc(TotalScoreExpression),
          desc(ScenariosCompletedExpression),
          desc(AccuracyAverageExpression),
          asc(AvgReactionExpression),
          asc(aim_scores.steam_id)
        )
        .limit(10);

      return c.json({
        data: {
          scores,
        },
      });
    } catch (e) {
      console.log(e);
      return c.json({ error: 'Internal server error' }, 500);
    }
  }
);

export default app;
