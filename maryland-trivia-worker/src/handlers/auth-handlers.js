import { jsonResponse, isValidDeviceId, readJsonBody } from '../helpers.js';
import {
  issueChallenge, consumeChallenge, upsertAttestation,
  issueTokens, verifyJWT,
  verifyAndroidChallengeSignature, verifyiOSAttestationNonce,
} from '../auth.js';

function jsonBodyError(error, corsHeaders) {
  return jsonResponse(
    { error: error.message || 'Invalid JSON body' },
    error.status || 400,
    corsHeaders
  );
}

async function secureCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const enc = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(a)),
    crypto.subtle.digest('SHA-256', enc.encode(b)),
  ]);
  const leftBytes = new Uint8Array(left);
  const rightBytes = new Uint8Array(right);
  let diff = leftBytes.length ^ rightBytes.length;
  for (let i = 0; i < Math.max(leftBytes.length, rightBytes.length); i++) {
    diff |= (leftBytes[i] || 0) ^ (rightBytes[i] || 0);
  }
  return diff === 0;
}

export async function handleChallenge(url, env, corsHeaders) {
  const deviceId = url.searchParams.get('deviceId');
  if (!isValidDeviceId(deviceId)) {
    return jsonResponse({ error: 'Invalid deviceId' }, 400, corsHeaders);
  }
  const nonce = await issueChallenge(deviceId, env);
  return jsonResponse({ challenge: nonce }, 200, corsHeaders);
}

export async function handleAttest(request, env, corsHeaders) {
  let body;
  try { body = await readJsonBody(request); } catch (error) { return jsonBodyError(error, corsHeaders); }
  const { deviceId, attestation, keyId, debugSecret, platform, publicKey } = body;
  if (!isValidDeviceId(deviceId)) {
    return jsonResponse({ error: 'Invalid deviceId' }, 400, corsHeaders);
  }

  if (debugSecret) {
    if (env.ENVIRONMENT === 'production') {
      console.warn(JSON.stringify({ level: 'warn', event: 'debug_auth_attempt_in_production', deviceId }));
      return jsonResponse({ error: 'Debug auth is disabled in production' }, 403, corsHeaders);
    }
    if (env.ENABLE_DEBUG_AUTH !== 'true') {
      return jsonResponse({ error: 'Debug auth is not enabled' }, 403, corsHeaders);
    }
    if (!env.DEBUG_SECRET || !(await secureCompare(debugSecret, env.DEBUG_SECRET))) {
      return jsonResponse({ error: 'Invalid debug secret' }, 403, corsHeaders);
    }
    const tokens = await issueTokens(deviceId, env);
    await upsertAttestation(env, deviceId, 'debug', tokens.refreshJti);
    return jsonResponse({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
    }, 200, corsHeaders);
  }

  const challengeNonce = await consumeChallenge(deviceId, env);
  if (!challengeNonce) {
    return jsonResponse({ error: 'No challenge found — request /auth/challenge first' }, 400, corsHeaders);
  }

  if (!attestation || !keyId) {
    return jsonResponse({ error: 'attestation and keyId required' }, 400, corsHeaders);
  }

  const existing = await env.DB.prepare(
    'SELECT key_id, revoked FROM attestations WHERE device_id = ?'
  ).bind(deviceId).first();

  if (existing?.revoked) {
    return jsonResponse({ error: 'Device has been revoked' }, 403, corsHeaders);
  }

  if (platform === 'android') {
    if (!publicKey) {
      return jsonResponse({ error: 'publicKey required for android attestation' }, 400, corsHeaders);
    }
    const signatureValid = await verifyAndroidChallengeSignature({
      challengeNonce, deviceId, keyId, attestation, publicKey,
    });
    if (!signatureValid) {
      return jsonResponse({ error: 'Invalid android attestation signature' }, 403, corsHeaders);
    }
    if (existing?.key_id && existing.key_id !== keyId && existing.key_id !== 'debug') {
      return jsonResponse({ error: 'Attestation key mismatch for device' }, 403, corsHeaders);
    }
    const tokens = await issueTokens(deviceId, env);
    await upsertAttestation(env, deviceId, keyId, tokens.refreshJti);
    return jsonResponse({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
    }, 200, corsHeaders);
  }

  const nonceValid = await verifyiOSAttestationNonce(challengeNonce, attestation);
  if (!nonceValid) {
    console.warn(JSON.stringify({ level: 'warn', event: 'ios_attest_nonce_fail', deviceId }));
    return jsonResponse({ error: 'Invalid iOS attestation' }, 403, corsHeaders);
  }
  if (existing?.key_id && existing.key_id !== keyId && existing.key_id !== 'debug') {
    return jsonResponse({ error: 'Attestation key mismatch for device' }, 403, corsHeaders);
  }

  const tokens = await issueTokens(deviceId, env);
  await upsertAttestation(env, deviceId, keyId, tokens.refreshJti);
  return jsonResponse({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresIn: tokens.expiresIn,
  }, 200, corsHeaders);
}

export async function handleRefresh(request, env, corsHeaders) {
  let body;
  try { body = await readJsonBody(request); } catch (error) { return jsonBodyError(error, corsHeaders); }
  const { refreshToken } = body;
  if (!refreshToken) {
    return jsonResponse({ error: 'refreshToken required' }, 400, corsHeaders);
  }
  const payload = await verifyJWT(refreshToken, env.JWT_SECRET);
  if (!payload || payload.type !== 'refresh') {
    return jsonResponse({ error: 'Invalid or expired refresh token' }, 401, corsHeaders);
  }
  const device = await env.DB.prepare(
    'SELECT revoked, last_refresh_jti FROM attestations WHERE device_id = ?'
  ).bind(payload.sub).first();
  if (!device) {
    return jsonResponse({ error: 'Device attestation not found' }, 401, corsHeaders);
  }
  if (device.revoked) {
    return jsonResponse({ error: 'Device revoked' }, 403, corsHeaders);
  }
  if (device.last_refresh_jti && payload.jti !== device.last_refresh_jti) {
    await env.DB.prepare(
      'UPDATE attestations SET revoked = 1 WHERE device_id = ?'
    ).bind(payload.sub).run();
    console.warn(JSON.stringify({ level: 'warn', event: 'refresh_token_reuse', deviceId: payload.sub }));
    return jsonResponse({ error: 'Refresh token reuse detected — device revoked' }, 401, corsHeaders);
  }
  const tokens = await issueTokens(payload.sub, env);
  await env.DB.prepare(
    'UPDATE attestations SET last_token_at = unixepoch(), last_refresh_jti = ? WHERE device_id = ?'
  ).bind(tokens.refreshJti, payload.sub).run();
  return jsonResponse({
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresIn: tokens.expiresIn,
  }, 200, corsHeaders);
}
