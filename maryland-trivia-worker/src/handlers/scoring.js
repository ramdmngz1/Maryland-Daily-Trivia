import {
  QUESTION_TIME, USERNAME_MAX_LENGTH,
  MAX_COMPLETION_TIME, SCORE_SUBMISSION_WINDOW,
} from '../constants.js';
import {
  jsonResponse, isBlockedUsername, isValidDeviceId, isValidQuestionId, readJsonBody,
} from '../helpers.js';

function calculateServerScore(answers, questions) {
  if (!Array.isArray(answers) || answers.length === 0) return null;
  if (answers.length > questions.length) return null;

  const questionMap = new Map(questions.map(q => [q.id, q.correct_index]));
  const seenQuestionIds = new Set();
  let score = 0;
  let totalTime = 0;

  for (const ans of answers) {
    if (!isValidQuestionId(ans.questionId)) return null;
    if (typeof ans.selectedIndex !== 'number' || !Number.isInteger(ans.selectedIndex)) return null;
    if (typeof ans.timeRemaining !== 'number' || !Number.isFinite(ans.timeRemaining)) return null;
    if (ans.selectedIndex < 0 || ans.selectedIndex > 3) return null;

    const correctIndex = questionMap.get(ans.questionId);
    if (correctIndex === undefined) return null;
    if (seenQuestionIds.has(ans.questionId)) return null;
    seenQuestionIds.add(ans.questionId);

    const t = Math.max(0, Math.min(QUESTION_TIME, ans.timeRemaining));
    totalTime += t;
    if (ans.selectedIndex === correctIndex) {
      score += Math.floor(1000 * (t / QUESTION_TIME));
    }
  }

  const completionTime = Math.max(0, answers.length * QUESTION_TIME - totalTime);
  return { score, completionTime };
}

export async function handleSubmitScore(request, roundId, authPayload, env, corsHeaders) {
  let body;
  try { body = await readJsonBody(request); } catch (error) {
    return jsonResponse({ error: error.message || 'Invalid JSON body' }, error.status || 400, corsHeaders);
  }

  if (!body.userId || !body.username || body.completionTime === undefined) {
    return jsonResponse({
      error: 'Missing required fields: userId, username, completionTime'
    }, 400, corsHeaders);
  }

  if (!isValidDeviceId(body.userId)) {
    return jsonResponse({ error: 'Invalid userId' }, 400, corsHeaders);
  }
  if (!authPayload || authPayload.sub !== body.userId) {
    return jsonResponse({ error: 'Forbidden' }, 403, corsHeaders);
  }
  const normalizedUsername = typeof body.username === 'string'
    ? body.username.trim().replace(/\s+/g, ' ')
    : '';
  if (normalizedUsername.length < 1 || normalizedUsername.length > USERNAME_MAX_LENGTH) {
    return jsonResponse({ error: `Invalid username (1-${USERNAME_MAX_LENGTH} characters)` }, 400, corsHeaders);
  }
  if (!/^[a-zA-Z0-9\s\-_.]+$/.test(normalizedUsername)) {
    return jsonResponse({ error: 'Username contains invalid characters' }, 400, corsHeaders);
  }
  if (isBlockedUsername(normalizedUsername)) {
    return jsonResponse({ error: 'Please choose a different username' }, 400, corsHeaders);
  }
  body.username = normalizedUsername;
  if (typeof body.completionTime !== 'number' || !Number.isFinite(body.completionTime) || body.completionTime < 0 || body.completionTime > MAX_COMPLETION_TIME) {
    return jsonResponse({ error: `Invalid completionTime (0-${MAX_COMPLETION_TIME})` }, 400, corsHeaders);
  }

  const round = await env.DB.prepare(
    'SELECT id, start_time, question_ids FROM rounds WHERE id = ?'
  ).bind(roundId).first();

  if (!round) {
    return jsonResponse({ error: 'Round not found' }, 404, corsHeaders);
  }

  const nowUnix = Math.floor(Date.now() / 1000);
  if (nowUnix - round.start_time > SCORE_SUBMISSION_WINDOW) {
    return jsonResponse({ error: 'Round expired — submissions are closed' }, 400, corsHeaders);
  }

  if (!Array.isArray(body.answers) || body.answers.length === 0) {
    return jsonResponse({ error: 'answers array is required' }, 400, corsHeaders);
  }

  const questionIds = JSON.parse(round.question_ids);
  const placeholders = questionIds.map(() => '?').join(',');
  const questionsResult = await env.DB.prepare(
    `SELECT id, correct_index FROM questions WHERE id IN (${placeholders})`
  ).bind(...questionIds).all();

  if (!questionsResult.success || questionsResult.results.length === 0) {
    return jsonResponse({ error: 'Failed to load round questions for scoring' }, 500, corsHeaders);
  }

  const serverScored = calculateServerScore(body.answers, questionsResult.results);
  if (!serverScored) {
    return jsonResponse({ error: 'Invalid answers payload' }, 400, corsHeaders);
  }

  const finalScore = serverScored.score;
  const finalCompletionTime = Math.floor(serverScored.completionTime);

  const insertResult = await env.DB.prepare(`
    INSERT OR IGNORE INTO scores (round_id, user_id, username, score, completion_time)
    VALUES (?, ?, ?, ?, ?)
  `).bind(roundId, body.userId, body.username, finalScore, finalCompletionTime).run();

  if (!insertResult.meta.changes) {
    const existing = await env.DB.prepare(
      'SELECT score, completion_time FROM scores WHERE round_id = ? AND user_id = ?'
    ).bind(roundId, body.userId).first();
    const existingRank = await env.DB.prepare(`
      SELECT COUNT(*) + 1 as rank FROM scores
      WHERE round_id = ? AND (score > ? OR (score = ? AND completion_time < ?))
    `).bind(roundId, existing.score, existing.score, existing.completion_time).first();
    return jsonResponse({
      success: true,
      rank: existingRank.rank,
      score: existing.score,
      duplicate: true,
    }, 200, corsHeaders);
  }

  await env.DB.prepare(
    'UPDATE scores SET username = ? WHERE user_id = ? AND username != ?'
  ).bind(body.username, body.userId, body.username).run();

  const rankResult = await env.DB.prepare(`
    SELECT COUNT(*) + 1 as rank
    FROM scores
    WHERE round_id = ? AND (
      score > ? OR
      (score = ? AND completion_time < ?)
    )
  `).bind(roundId, finalScore, finalScore, finalCompletionTime).first();

  return jsonResponse({
    success: true,
    rank: rankResult.rank,
    score: finalScore,
  }, 200, corsHeaders);
}
