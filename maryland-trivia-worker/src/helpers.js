import {
  ROUND_DURATION, ROUND_ID_REGEX, DEVICE_ID_REGEX, QUESTION_ID_REGEX,
  USERNAME_BLOCKLIST_REGEX, MAX_JSON_BODY_BYTES,
} from './constants.js';

export function jsonResponse(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
  });
}

export function isValidRoundId(roundId) {
  return typeof roundId === 'string' && ROUND_ID_REGEX.test(roundId);
}

export function isValidDeviceId(deviceId) {
  return typeof deviceId === 'string' && DEVICE_ID_REGEX.test(deviceId);
}

export function isValidQuestionId(questionId) {
  return typeof questionId === 'string' && QUESTION_ID_REGEX.test(questionId);
}

export function isBlockedUsername(username) {
  return USERNAME_BLOCKLIST_REGEX.test(username);
}

export async function readJsonBody(request, maxBytes = MAX_JSON_BODY_BYTES) {
  const declaredLength = request.headers.get('Content-Length');
  if (declaredLength && Number(declaredLength) > maxBytes) {
    const error = new Error('Request body too large');
    error.status = 413;
    throw error;
  }

  const raw = await request.text();
  if (new TextEncoder().encode(raw).byteLength > maxBytes) {
    const error = new Error('Request body too large');
    error.status = 413;
    throw error;
  }

  try {
    return JSON.parse(raw);
  } catch {
    const error = new Error('Invalid JSON body');
    error.status = 400;
    throw error;
  }
}

export function getCurrentRoundInfo() {
  const now = Date.now();
  const roundStartTime = Math.floor(now / (ROUND_DURATION * 1000)) * (ROUND_DURATION * 1000);
  const date = new Date(roundStartTime);
  const roundId = `round_${date.toISOString().slice(0, 19).replace('T', '_').replace(/:/g, '-')}`;
  return { roundId, roundStartTime, now };
}
