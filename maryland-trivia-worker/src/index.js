import {
  QUESTION_TIME, EXPLANATION_TIME, RESULTS_TIME, LEADERBOARD_TIME,
  QUESTIONS_PER_ROUND, QUESTION_CYCLE, QUIZ_DURATION, ROUND_DURATION,
  RATE_LIMIT_MAX_REQUESTS,
} from './constants.js';
import { jsonResponse, isValidRoundId } from './helpers.js';
import { rateLimitBucketFor, checkRateLimit } from './rate-limit.js';
import { authenticateRequest } from './auth.js';
import { handleChallenge, handleAttest, handleRefresh } from './handlers/auth-handlers.js';
import { handleGetLiveState, handleGetCurrentRound, handleGetRound } from './handlers/rounds.js';
import { handleSubmitScore } from './handlers/scoring.js';
import {
  handleGetDailyLeaderboard, handleGetLeaderboard,
  handleGetUserStats, handleGetQuestions, handleDeleteUser,
} from './handlers/data.js';

export default {
  async fetch(request, env) {
    if (!env.JWT_SECRET || env.JWT_SECRET.length < 32) {
      return jsonResponse({ error: 'Server misconfiguration' }, 500);
    }

    const url = new URL(request.url);

    const origin = request.headers.get('Origin') || '';
    const allowedOrigins = [
      'https://maryland-trivia-contest.f22682jcz6.workers.dev',
    ];
    const corsOrigin = allowedOrigins.includes(origin) ? origin : null;
    const corsHeaders = {
      ...(corsOrigin && { 'Access-Control-Allow-Origin': corsOrigin }),
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Content-Security-Policy': "default-src 'none'",
      'Referrer-Policy': 'no-referrer',
      'Permissions-Policy': 'interest-cohort=()',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rateBucket = rateLimitBucketFor(url.pathname, request.method);
    const maxRequests = RATE_LIMIT_MAX_REQUESTS[rateBucket] ?? RATE_LIMIT_MAX_REQUESTS.default;
    const limit = await checkRateLimit(clientIP, rateBucket, maxRequests, env);
    if (limit.limited) {
      return jsonResponse({
        error: 'Too many requests',
        retryAfterSeconds: limit.retryAfter,
      }, 429, {
        ...corsHeaders,
        'Retry-After': String(limit.retryAfter),
      });
    }

    try {
      // ── Auth (no JWT required) ──

      if (url.pathname === '/auth/challenge' && request.method === 'GET') {
        return await handleChallenge(url, env, corsHeaders);
      }

      if (url.pathname === '/auth/attest' && request.method === 'POST') {
        return await handleAttest(request, env, corsHeaders);
      }

      if (url.pathname === '/auth/refresh' && request.method === 'POST') {
        return await handleRefresh(request, env, corsHeaders);
      }

      // ── Game state ──

      if (url.pathname === '/api/live-state') {
        return await handleGetLiveState(env, corsHeaders);
      }

      if (url.pathname === '/api/rounds/current') {
        return await handleGetCurrentRound(env, corsHeaders);
      }

      if (url.pathname.match(/^\/api\/rounds\/[^/]+$/)) {
        const roundId = decodeURIComponent(url.pathname.split('/')[3]);
        if (!isValidRoundId(roundId)) {
          return jsonResponse({ error: 'Invalid round ID format' }, 400, corsHeaders);
        }
        return await handleGetRound(roundId, env, corsHeaders);
      }

      // ── Score submission (auth required) ──

      if (url.pathname.match(/^\/api\/rounds\/[^/]+\/score$/)) {
        if (request.method !== 'POST') {
          return jsonResponse({ error: 'Method not allowed' }, 405, corsHeaders);
        }
        const authPayload = await authenticateRequest(request, env);
        if (!authPayload) {
          return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const roundId = decodeURIComponent(url.pathname.split('/')[3]);
        if (!isValidRoundId(roundId)) {
          return jsonResponse({ error: 'Invalid round ID format' }, 400, corsHeaders);
        }
        return await handleSubmitScore(request, roundId, authPayload, env, corsHeaders);
      }

      // ── Leaderboards & stats ──

      if (url.pathname === '/api/leaderboard/daily') {
        return await handleGetDailyLeaderboard(env, corsHeaders);
      }

      if (url.pathname.match(/^\/api\/leaderboard\/[^/]+$/)) {
        const roundId = decodeURIComponent(url.pathname.split('/')[3]);
        if (!isValidRoundId(roundId)) {
          return jsonResponse({ error: 'Invalid round ID format' }, 400, corsHeaders);
        }
        return await handleGetLeaderboard(roundId, env, corsHeaders);
      }

      if (url.pathname.match(/^\/api\/user\/[^/]+\/stats$/)) {
        const userId = decodeURIComponent(url.pathname.split('/')[3]);
        return await handleGetUserStats(userId, env, corsHeaders);
      }

      // ── User deletion (auth required, self-only) ──

      if (url.pathname.match(/^\/api\/user\/[^/]+$/) && request.method === 'DELETE') {
        const authPayload = await authenticateRequest(request, env);
        if (!authPayload) {
          return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const userId = decodeURIComponent(url.pathname.split('/')[3]);
        if (authPayload.sub !== userId) {
          return jsonResponse({ error: 'Forbidden' }, 403, corsHeaders);
        }
        return await handleDeleteUser(userId, env, corsHeaders);
      }

      // ── Questions (auth required) ──

      if (url.pathname === '/api/questions' && request.method === 'POST') {
        if (!(await authenticateRequest(request, env))) {
          return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        return await handleGetQuestions(request, env, corsHeaders);
      }

      // ── Config & health ──

      if (url.pathname === '/api/config') {
        return jsonResponse({
          questionTime: QUESTION_TIME,
          explanationTime: EXPLANATION_TIME,
          resultsTime: RESULTS_TIME,
          leaderboardTime: LEADERBOARD_TIME,
          questionsPerRound: QUESTIONS_PER_ROUND,
          questionCycle: QUESTION_CYCLE,
          quizDuration: QUIZ_DURATION,
          roundDuration: ROUND_DURATION,
        }, 200, {
          ...corsHeaders,
          'Cache-Control': 'public, max-age=3600',
        });
      }

      if (url.pathname === '/health') {
        try {
          await env.DB.prepare('SELECT 1').first();
          return jsonResponse({ status: 'ok', db: 'connected' }, 200, corsHeaders);
        } catch {
          return jsonResponse({ status: 'degraded', db: 'unreachable' }, 503, corsHeaders);
        }
      }

      return jsonResponse({ error: 'Not found' }, 404, corsHeaders);

    } catch (error) {
      const requestId = crypto.randomUUID();
      console.error(JSON.stringify({
        level: 'error',
        requestId,
        path: url.pathname,
        method: request.method,
        message: error.message,
        stack: error.stack,
      }));
      return jsonResponse({
        error: 'Internal server error',
        requestId,
      }, 500, corsHeaders);
    }
  },
};
