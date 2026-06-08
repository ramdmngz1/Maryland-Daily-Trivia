import { MAX_QUESTION_IDS_PER_REQUEST } from '../constants.js';
import { jsonResponse, isValidDeviceId, isValidQuestionId, readJsonBody } from '../helpers.js';

export async function handleGetDailyLeaderboard(env, corsHeaders) {
  const results = await env.DB.prepare(`
    WITH recent AS (
      SELECT user_id, username, score,
             ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY submitted_at DESC) as rn
      FROM scores
      WHERE submitted_at > unixepoch() - 86400
    )
    SELECT user_id,
           MAX(CASE WHEN rn = 1 THEN username END) as username,
           SUM(score) as total_score,
           COUNT(*) as rounds_played
    FROM recent
    GROUP BY user_id
    ORDER BY total_score DESC
    LIMIT 10
  `).all();

  if (!results.success) {
    return jsonResponse({ error: 'Failed to fetch daily leaderboard' }, 500, corsHeaders);
  }

  const entries = results.results.map((entry, index) => ({
    rank: index + 1,
    userId: entry.user_id,
    username: entry.username,
    totalScore: entry.total_score,
    roundsPlayed: entry.rounds_played,
  }));

  return jsonResponse({ entries, total: entries.length }, 200, {
    ...corsHeaders,
    'Cache-Control': 'public, max-age=30',
  });
}

export async function handleGetLeaderboard(roundId, env, corsHeaders) {
  const results = await env.DB.prepare(`
    SELECT user_id, username, score, completion_time, submitted_at
    FROM scores
    WHERE round_id = ?
    ORDER BY score DESC, completion_time ASC
    LIMIT 100
  `).bind(roundId).all();

  if (!results.success) {
    return jsonResponse({ error: 'Failed to fetch leaderboard' }, 500, corsHeaders);
  }

  const leaderboard = results.results.map((entry, index) => ({
    rank: index + 1,
    userId: entry.user_id,
    username: entry.username,
    score: entry.score,
    completionTime: entry.completion_time,
    submittedAt: entry.submitted_at * 1000,
  }));

  return jsonResponse({
    roundId,
    entries: leaderboard,
    total: leaderboard.length,
  }, 200, {
    ...corsHeaders,
    'Cache-Control': 'public, max-age=30',
  });
}

export async function handleGetUserStats(userId, env, corsHeaders) {
  if (!isValidDeviceId(userId)) {
    return jsonResponse({ error: 'Invalid userId' }, 400, corsHeaders);
  }

  const stats = await env.DB.prepare(`
    SELECT
      COUNT(*) as total_rounds,
      AVG(score) as avg_score,
      MAX(score) as best_score,
      MIN(score) as worst_score,
      SUM(CASE WHEN score > 0 THEN 1 ELSE 0 END) as rounds_completed
    FROM scores
    WHERE user_id = ?
  `).bind(userId).first();

  const bestRankResult = await env.DB.prepare(`
    WITH ranked AS (
      SELECT round_id, user_id,
        ROW_NUMBER() OVER (PARTITION BY round_id ORDER BY score DESC, completion_time ASC) as rank
      FROM scores
      WHERE round_id IN (SELECT round_id FROM scores WHERE user_id = ?)
    )
    SELECT MIN(rank) as best_rank FROM ranked WHERE user_id = ?
  `).bind(userId, userId).first();

  return jsonResponse({
    userId,
    totalRounds: stats.total_rounds || 0,
    roundsCompleted: stats.rounds_completed || 0,
    avgScore: Math.round(stats.avg_score || 0),
    bestScore: stats.best_score || 0,
    worstScore: stats.worst_score || 0,
    bestRank: bestRankResult.best_rank || null,
  }, 200, {
    ...corsHeaders,
    'Cache-Control': 'public, max-age=60',
  });
}

export async function handleGetQuestions(request, env, corsHeaders) {
  let body;
  try { body = await readJsonBody(request); } catch (error) {
    return jsonResponse({ error: error.message || 'Invalid JSON body' }, error.status || 400, corsHeaders);
  }

  if (!body.ids || !Array.isArray(body.ids) || body.ids.length === 0 || body.ids.length > MAX_QUESTION_IDS_PER_REQUEST) {
    return jsonResponse({ error: `ids array must contain 1-${MAX_QUESTION_IDS_PER_REQUEST} items` }, 400, corsHeaders);
  }

  if (!body.ids.every(isValidQuestionId)) {
    return jsonResponse({ error: 'Invalid question ID format' }, 400, corsHeaders);
  }

  const placeholders = body.ids.map(() => '?').join(',');

  const results = await env.DB.prepare(`
    SELECT id, category, difficulty, question, choices, correct_index, explanation FROM questions WHERE id IN (${placeholders})
  `).bind(...body.ids).all();

  if (!results.success) {
    return jsonResponse({ error: 'Failed to fetch questions' }, 500, corsHeaders);
  }

  const questions = results.results.map(q => {
    let choices;
    try {
      if (Array.isArray(q.choices)) {
        choices = q.choices;
      } else if (typeof q.choices === 'string') {
        choices = JSON.parse(q.choices);
      } else {
        console.error(`Invalid choices format for ${q.id}:`, typeof q.choices);
        choices = ['Error', 'Error', 'Error', 'Error'];
      }
    } catch (parseError) {
      console.error(`Failed to parse choices for ${q.id}:`, parseError.message);
      choices = ['Error', 'Error', 'Error', 'Error'];
    }

    return {
      id: q.id,
      category: q.category,
      difficulty: q.difficulty || 'medium',
      question: q.question,
      choices,
      correctIndex: q.correct_index,
      explanation: q.explanation || '',
    };
  });

  return jsonResponse({ questions }, 200, {
    ...corsHeaders,
    'Cache-Control': 'public, max-age=3600',
  });
}

export async function handleDeleteUser(userId, env, corsHeaders) {
  if (!isValidDeviceId(userId)) {
    return jsonResponse({ error: 'Invalid userId' }, 400, corsHeaders);
  }

  await env.DB.prepare('DELETE FROM scores WHERE user_id = ?').bind(userId).run();
  await env.DB.prepare('DELETE FROM attestations WHERE device_id = ?').bind(userId).run();
  return jsonResponse({ success: true }, 200, corsHeaders);
}
