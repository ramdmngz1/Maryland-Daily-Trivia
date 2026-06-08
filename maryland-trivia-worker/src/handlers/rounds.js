import {
  QUESTION_TIME, EXPLANATION_TIME, RESULTS_TIME, LEADERBOARD_TIME,
  QUESTIONS_PER_ROUND, QUESTION_CYCLE, QUIZ_DURATION, ROUND_DURATION,
  LOOKBACK_ROUNDS,
} from '../constants.js';
import { jsonResponse, getCurrentRoundInfo } from '../helpers.js';

let cachedPlayerCount = { count: 0, fetchedAt: 0 };
let cachedCurrentRound = null;
let cachedLiveState = null;

async function selectRandomQuestions(db, count) {
  const result = await db.prepare(`
    SELECT id FROM questions
    WHERE id NOT IN (
      SELECT DISTINCT je.value
      FROM (SELECT question_ids FROM rounds ORDER BY start_time DESC LIMIT ?) r
      JOIN json_each(r.question_ids) je
    )
    ORDER BY RANDOM()
    LIMIT ?
  `).bind(LOOKBACK_ROUNDS, count).all();

  if (result.success && result.results.length >= count) {
    return result.results.map(row => row.id);
  }

  const fallback = await db.prepare(
    'SELECT id FROM questions ORDER BY RANDOM() LIMIT ?'
  ).bind(count).all();

  if (!fallback.success || fallback.results.length === 0) {
    throw new Error('No questions available in database');
  }

  return fallback.results.map(row => row.id);
}

function normalizeRound(row) {
  if (!row) return null;
  return {
    id: row.id,
    startTimeSeconds: row.start_time,
    questionIds: JSON.parse(row.question_ids),
    status: row.status,
  };
}

async function getOrCreateRound(roundId, roundStartTime, env) {
  if (cachedCurrentRound?.id === roundId) {
    return cachedCurrentRound;
  }

  let round = await env.DB.prepare(
    'SELECT id, start_time, question_ids, status FROM rounds WHERE id = ?'
  ).bind(roundId).first();

  if (!round) {
    const questionIds = await selectRandomQuestions(env.DB, QUESTIONS_PER_ROUND);
    const startTimeSeconds = Math.floor(roundStartTime / 1000);
    const insertResult = await env.DB.prepare(
      'INSERT OR IGNORE INTO rounds (id, start_time, question_ids, status) VALUES (?, ?, ?, ?)'
    ).bind(
      roundId,
      startTimeSeconds,
      JSON.stringify(questionIds),
      'active'
    ).run();

    if (insertResult.meta.changes) {
      cachedCurrentRound = {
        id: roundId,
        startTimeSeconds,
        questionIds,
        status: 'active',
      };
      return cachedCurrentRound;
    }

    round = await env.DB.prepare(
      'SELECT id, start_time, question_ids, status FROM rounds WHERE id = ?'
    ).bind(roundId).first();

  }

  cachedCurrentRound = normalizeRound(round);
  return cachedCurrentRound;
}

export async function handleGetLiveState(env, corsHeaders) {
  const { roundId, roundStartTime, now } = getCurrentRoundInfo();
  const elapsedInRound = (now - roundStartTime) / 1000;

  const round = await getOrCreateRound(roundId, roundStartTime, env);

  let phase, currentQuestionIndex, secondsRemaining, nextRoundStartsIn;

  if (elapsedInRound < QUIZ_DURATION) {
    const elapsedInQuiz = elapsedInRound;
    currentQuestionIndex = Math.floor(elapsedInQuiz / QUESTION_CYCLE);
    const timeInCycle = elapsedInQuiz % QUESTION_CYCLE;

    if (timeInCycle < QUESTION_TIME) {
      phase = 'question';
      secondsRemaining = Math.ceil(QUESTION_TIME - timeInCycle);
    } else {
      phase = 'explanation';
      secondsRemaining = Math.ceil(EXPLANATION_TIME - (timeInCycle - QUESTION_TIME));
    }
    nextRoundStartsIn = null;
  } else if (elapsedInRound < QUIZ_DURATION + RESULTS_TIME) {
    phase = 'results';
    currentQuestionIndex = -1;
    secondsRemaining = Math.ceil(RESULTS_TIME - (elapsedInRound - QUIZ_DURATION));
    nextRoundStartsIn = Math.ceil(ROUND_DURATION - elapsedInRound);
  } else {
    phase = 'leaderboard';
    currentQuestionIndex = -1;
    secondsRemaining = Math.ceil(LEADERBOARD_TIME - (elapsedInRound - QUIZ_DURATION - RESULTS_TIME));
    nextRoundStartsIn = Math.ceil(ROUND_DURATION - elapsedInRound);
  }

  if (now - cachedPlayerCount.fetchedAt > 10_000) {
    const playerCountResult = await env.DB.prepare(`
      SELECT COUNT(DISTINCT user_id) as count
      FROM scores
      WHERE submitted_at > unixepoch() - 300
    `).first();
    cachedPlayerCount = { count: playerCountResult?.count || 0, fetchedAt: now };
  }

  const liveStateCacheKey = [
    roundId,
    phase,
    currentQuestionIndex,
    secondsRemaining,
    nextRoundStartsIn ?? '',
    cachedPlayerCount.count,
  ].join('|');

  if (cachedLiveState?.key === liveStateCacheKey && now < cachedLiveState.expiresAt) {
    return jsonResponse(cachedLiveState.payload, 200, corsHeaders);
  }

  const payload = {
    roundId,
    currentQuestionIndex,
    phase,
    secondsRemaining,
    questionIds: round.questionIds,
    nextRoundStartsIn,
    activePlayerCount: cachedPlayerCount.count,
    roundStartTime,
  };

  cachedLiveState = {
    key: liveStateCacheKey,
    payload,
    expiresAt: now + 250,
  };

  return jsonResponse(payload, 200, corsHeaders);
}

export async function handleGetCurrentRound(env, corsHeaders) {
  const { roundId, roundStartTime } = getCurrentRoundInfo();
  const round = await getOrCreateRound(roundId, roundStartTime, env);

  return jsonResponse({
    id: round.id,
    startTime: round.startTimeSeconds * 1000,
    questionIds: round.questionIds,
    status: round.status,
  }, 200, corsHeaders);
}

export async function handleGetRound(roundId, env, corsHeaders) {
  const round = await env.DB.prepare(
    'SELECT id, start_time, question_ids, status FROM rounds WHERE id = ?'
  ).bind(roundId).first();

  if (!round) {
    return jsonResponse({ error: 'Round not found' }, 404, corsHeaders);
  }

  return jsonResponse({
    id: round.id,
    startTime: round.start_time * 1000,
    questionIds: JSON.parse(round.question_ids),
    status: round.status,
  }, 200, corsHeaders);
}
