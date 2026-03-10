// Maryland Trivia Contest API - Cloudflare Worker
// Main entry point for all API endpoints
// Live Trivia System - AMI/Crowdpurr style

// RATE LIMITING (in-memory, per-isolate)
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const RATE_LIMIT_MAX_REQUESTS = {
  default: 60,
  liveState: 90,
  leaderboard: 30,
  auth: 30,
  write: 30,
  questions: 40,
};
const rateLimitMap = new Map();

// CACHED ACTIVE PLAYER COUNT (per-isolate, 10s TTL)
let cachedPlayerCount = { count: 0, fetchedAt: 0 };

function rateLimitBucketFor(pathname, method) {
  if (pathname === '/api/live-state') return 'liveState';
  if (pathname.startsWith('/api/leaderboard/')) return 'leaderboard';
  if (pathname.startsWith('/auth/')) return 'auth';
  if (pathname === '/api/questions') return 'questions';
  if (method === 'POST' && pathname.match(/^\/api\/rounds\/[^/]+\/score$/)) return 'write';
  if (method === 'DELETE' && pathname.match(/^\/api\/user\/[^/]+$/)) return 'write';
  return 'default';
}

function checkRateLimit(ip, bucket, maxRequests) {
  const now = Date.now();
  const key = `${ip}:${bucket}`;
  const entry = rateLimitMap.get(key);
  if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateLimitMap.set(key, { windowStart: now, count: 1 });
    return { limited: false, retryAfter: 0 };
  }

  entry.count++;
  if (entry.count > maxRequests) {
    const retryAfter = Math.max(1, Math.ceil((entry.windowStart + RATE_LIMIT_WINDOW_MS - now) / 1000));
    return { limited: true, retryAfter };
  }
  return { limited: false, retryAfter: 0 };
}

// ROUND ID VALIDATION
const ROUND_ID_REGEX = /^round_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/;

function isValidRoundId(roundId) {
  return typeof roundId === 'string' && ROUND_ID_REGEX.test(roundId);
}

// ── JWT HELPERS (HS256 via Web Crypto) ──────────────────────────────

function base64url(buf) {
  const bytes = buf instanceof ArrayBuffer ? new Uint8Array(buf) : buf;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlDecode(str) {
  const padded = str.replace(/-/g, '+').replace(/_/g, '/') +
    '='.repeat((4 - (str.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

async function sha256Base64Url(bytes) {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return base64url(digest);
}

function toArrayBuffer(bytes) {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
}

async function verifyAndroidChallengeSignature({ challengeNonce, deviceId, keyId, attestation, publicKey }) {
  if (!challengeNonce || !deviceId || !keyId || !attestation || !publicKey) return false;

  let publicKeyBytes;
  let signatureBytes;
  try {
    publicKeyBytes = base64urlDecode(publicKey);
    signatureBytes = base64urlDecode(attestation);
  } catch {
    return false;
  }

  const expectedKeyId = `android_${await sha256Base64Url(publicKeyBytes)}`;
  if (expectedKeyId !== keyId) return false;

  let cryptoKey;
  try {
    cryptoKey = await crypto.subtle.importKey(
      'spki',
      toArrayBuffer(publicKeyBytes),
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify']
    );
  } catch {
    return false;
  }

  const payload = `${challengeNonce}:${deviceId}:${keyId}`;
  return crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    toArrayBuffer(signatureBytes),
    new TextEncoder().encode(payload)
  );
}

async function createJWT(payload, secret) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const enc = new TextEncoder();
  const signingInput =
    base64url(enc.encode(JSON.stringify(header))) + '.' +
    base64url(enc.encode(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(signingInput));
  return signingInput + '.' + base64url(sig);
}

async function verifyJWT(token, secret) {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']
  );
  const valid = await crypto.subtle.verify(
    'HMAC', key, base64urlDecode(parts[2]), enc.encode(parts[0] + '.' + parts[1])
  );
  if (!valid) return null;
  const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[1])));
  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
  return payload;
}

async function issueTokens(deviceId, env) {
  const now = Math.floor(Date.now() / 1000);
  const accessToken = await createJWT(
    { sub: deviceId, iat: now, exp: now + 3600, iss: 'maryland-trivia-worker', type: 'access' },
    env.JWT_SECRET
  );
  const refreshToken = await createJWT(
    { sub: deviceId, iat: now, exp: now + 30 * 86400, iss: 'maryland-trivia-worker', type: 'refresh' },
    env.JWT_SECRET
  );
  return { accessToken, refreshToken, expiresIn: 3600 };
}

// Authenticate via Bearer JWT and check device revocation
async function authenticateRequest(request, env) {
  const authHeader = request.headers.get('Authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    const payload = await verifyJWT(token, env.JWT_SECRET);
    if (payload && payload.type === 'access') {
      // Check device revocation
      const device = await env.DB.prepare(
        'SELECT revoked FROM attestations WHERE device_id = ?'
      ).bind(payload.sub).first();
      if (device && device.revoked) return null;
      return payload;
    }
  }
  return null;
}

// In-memory nonce store (per-isolate; short-lived challenges)
const challengeMap = new Map();

// TIMING CONSTANTS
const QUESTION_TIME = 12;      // seconds for answering
const EXPLANATION_TIME = 10;   // seconds showing explanation (UPDATED: was 5)
const RESULTS_TIME = 10;       // seconds showing results
const LEADERBOARD_TIME = 20;   // seconds showing leaderboard
const QUESTIONS_PER_ROUND = 10;
const QUESTION_CYCLE = QUESTION_TIME + EXPLANATION_TIME; // 22 seconds (was 17)
const QUIZ_DURATION = QUESTION_CYCLE * QUESTIONS_PER_ROUND; // 220 seconds (was 170)
const ROUND_DURATION = QUIZ_DURATION + RESULTS_TIME + LEADERBOARD_TIME; // 250 seconds (4min 10sec, was 3min 20sec)

export default {
  async fetch(request, env) {
    // Validate JWT_SECRET exists and is strong enough
    if (!env.JWT_SECRET || env.JWT_SECRET.length < 32) {
      return new Response(JSON.stringify({ error: 'Server misconfiguration' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const url = new URL(request.url);

    // CORS headers — only set Access-Control-Allow-Origin for known origins
    const origin = request.headers.get('Origin') || '';
    const allowedOrigins = [
      'https://maryland-trivia-contest.f22682jcz6.workers.dev',
      // Add your app's web domain here if needed
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
    
    // Handle preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Rate limiting
    const clientIP = request.headers.get('CF-Connecting-IP') || 'unknown';
    const rateBucket = rateLimitBucketFor(url.pathname, request.method);
    const maxRequests = RATE_LIMIT_MAX_REQUESTS[rateBucket] ?? RATE_LIMIT_MAX_REQUESTS.default;
    const limit = checkRateLimit(clientIP, rateBucket, maxRequests);
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
      // ── Auth endpoints (no auth required) ──

      // GET /auth/challenge?deviceId=X — returns a one-time nonce
      if (url.pathname === '/auth/challenge' && request.method === 'GET') {
        const deviceId = url.searchParams.get('deviceId');
        if (!deviceId || deviceId.length > 200) {
          return jsonResponse({ error: 'deviceId required' }, 400, corsHeaders);
        }
        const buf = new Uint8Array(32);
        crypto.getRandomValues(buf);
        const nonce = Array.from(buf).map(b => b.toString(16).padStart(2, '0')).join('');
        challengeMap.set(deviceId, { nonce, created: Date.now() });
        // Expire old challenges
        for (const [k, v] of challengeMap) {
          if (Date.now() - v.created > 300_000) challengeMap.delete(k);
        }
        return jsonResponse({ challenge: nonce }, 200, corsHeaders);
      }

      // POST /auth/attest — validate attestation and issue tokens
      if (url.pathname === '/auth/attest' && request.method === 'POST') {
        let body;
        try { body = await request.json(); } catch { return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders); }
        const { deviceId, attestation, keyId, debugSecret, platform, publicKey } = body;
        if (!deviceId) {
          return jsonResponse({ error: 'deviceId required' }, 400, corsHeaders);
        }

        // Debug bypass — only available when ENABLE_DEBUG_AUTH is explicitly set
        // BLOCKED in production regardless of flag
        if (debugSecret) {
          if (env.ENVIRONMENT === 'production') {
            console.warn(JSON.stringify({ level: 'warn', event: 'debug_auth_attempt_in_production', deviceId }));
            return jsonResponse({ error: 'Debug auth is disabled in production' }, 403, corsHeaders);
          }
          if (env.ENABLE_DEBUG_AUTH !== 'true') {
            return jsonResponse({ error: 'Debug auth is not enabled' }, 403, corsHeaders);
          }
          if (!env.DEBUG_SECRET || debugSecret !== env.DEBUG_SECRET) {
            return jsonResponse({ error: 'Invalid debug secret' }, 403, corsHeaders);
          }
          await env.DB.prepare(`
            INSERT INTO attestations (device_id, key_id, attested_at, last_token_at, revoked)
            VALUES (?, ?, unixepoch(), unixepoch(), 0)
            ON CONFLICT(device_id) DO UPDATE SET last_token_at = unixepoch()
          `).bind(deviceId, 'debug').run();

          const tokens = await issueTokens(deviceId, env);
          return jsonResponse(tokens, 200, corsHeaders);
        }

        // Real attestation: verify challenge was issued
        const challenge = challengeMap.get(deviceId);
        if (!challenge) {
          return jsonResponse({ error: 'No challenge found — request /auth/challenge first' }, 400, corsHeaders);
        }
        challengeMap.delete(deviceId);

        if (!attestation || !keyId) {
          return jsonResponse({ error: 'attestation and keyId required' }, 400, corsHeaders);
        }

        const existing = await env.DB.prepare(
          'SELECT key_id FROM attestations WHERE device_id = ?'
        ).bind(deviceId).first();

        // Android challenge-signature attestation
        if (platform === 'android') {
          if (!publicKey) {
            return jsonResponse({ error: 'publicKey required for android attestation' }, 400, corsHeaders);
          }

          const signatureValid = await verifyAndroidChallengeSignature({
            challengeNonce: challenge.nonce,
            deviceId,
            keyId,
            attestation,
            publicKey,
          });
          if (!signatureValid) {
            return jsonResponse({ error: 'Invalid android attestation signature' }, 403, corsHeaders);
          }

          if (existing?.key_id && existing.key_id !== keyId && existing.key_id !== 'debug') {
            return jsonResponse({ error: 'Attestation key mismatch for device' }, 403, corsHeaders);
          }

          await env.DB.prepare(`
            INSERT INTO attestations (device_id, key_id, attested_at, last_token_at, revoked)
            VALUES (?, ?, unixepoch(), unixepoch(), 0)
            ON CONFLICT(device_id) DO UPDATE SET key_id = ?, last_token_at = unixepoch()
          `).bind(deviceId, keyId, keyId).run();

          const tokens = await issueTokens(deviceId, env);
          return jsonResponse(tokens, 200, corsHeaders);
        }

        // iOS path: store attestation metadata.
        // Full server-side Apple attestation verification requires CBOR and
        // certificate-chain validation, which is intentionally deferred here.
        await env.DB.prepare(`
          INSERT INTO attestations (device_id, key_id, attested_at, last_token_at, revoked)
          VALUES (?, ?, unixepoch(), unixepoch(), 0)
          ON CONFLICT(device_id) DO UPDATE SET key_id = ?, last_token_at = unixepoch()
        `).bind(deviceId, keyId, keyId).run();

        const tokens = await issueTokens(deviceId, env);
        return jsonResponse(tokens, 200, corsHeaders);
      }

      // POST /auth/refresh — exchange refresh token for new access token
      if (url.pathname === '/auth/refresh' && request.method === 'POST') {
        let body;
        try { body = await request.json(); } catch { return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders); }
        const { refreshToken } = body;
        if (!refreshToken) {
          return jsonResponse({ error: 'refreshToken required' }, 400, corsHeaders);
        }
        const payload = await verifyJWT(refreshToken, env.JWT_SECRET);
        if (!payload || payload.type !== 'refresh') {
          return jsonResponse({ error: 'Invalid or expired refresh token' }, 401, corsHeaders);
        }
        // Check device not revoked
        const device = await env.DB.prepare(
          'SELECT revoked FROM attestations WHERE device_id = ?'
        ).bind(payload.sub).first();
        if (device && device.revoked) {
          return jsonResponse({ error: 'Device revoked' }, 403, corsHeaders);
        }
        // Issue new access token only
        const now = Math.floor(Date.now() / 1000);
        const accessToken = await createJWT(
          { sub: payload.sub, iat: now, exp: now + 3600, iss: 'maryland-trivia-worker', type: 'access' },
          env.JWT_SECRET
        );
        return jsonResponse({ accessToken, expiresIn: 3600 }, 200, corsHeaders);
      }

      // ── Route handling ──

      // NEW: Live state endpoint (primary endpoint for live trivia)
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

      if (url.pathname.match(/^\/api\/rounds\/[^/]+\/score$/)) {
        if (request.method !== 'POST') {
          return jsonResponse({ error: 'Method not allowed' }, 405, corsHeaders);
        }
        if (!(await authenticateRequest(request, env))) {
          return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const roundId = decodeURIComponent(url.pathname.split('/')[3]);
        if (!isValidRoundId(roundId)) {
          return jsonResponse({ error: 'Invalid round ID format' }, 400, corsHeaders);
        }
        return await handleSubmitScore(request, roundId, env, corsHeaders);
      }

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
        const userId = url.pathname.split('/')[3];
        return await handleGetUserStats(userId, env, corsHeaders);
      }

      // DELETE /api/user/:userId — GDPR/CCPA right to erasure
      if (url.pathname.match(/^\/api\/user\/[^/]+$/) && request.method === 'DELETE') {
        const authPayload = await authenticateRequest(request, env);
        if (!authPayload) {
          return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const userId = url.pathname.split('/')[3];
        if (authPayload.sub !== userId) {
          return jsonResponse({ error: 'Forbidden' }, 403, corsHeaders);
        }
        return await handleDeleteUser(userId, env, corsHeaders);
      }
      
      // Get questions by IDs
      if (url.pathname === '/api/questions' && request.method === 'POST') {
        if (!(await authenticateRequest(request, env))) {
          return jsonResponse({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        return await handleGetQuestions(request, env, corsHeaders);
      }
      
      // Game timing configuration (cacheable, fetched once per app session)
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

      // Health check with DB connectivity verification
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

// Helper function for JSON responses
function jsonResponse(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
  });
}

// Helper: Get or create a round, handling race conditions
async function getOrCreateRound(roundId, roundStartTime, env) {
  let round = await env.DB.prepare('SELECT * FROM rounds WHERE id = ?').bind(roundId).first();
  if (!round) {
    const questionIds = await selectRandomQuestions(env.DB, QUESTIONS_PER_ROUND);
    await env.DB.prepare(
      'INSERT OR IGNORE INTO rounds (id, start_time, question_ids, status) VALUES (?, ?, ?, ?)'
    ).bind(
      roundId,
      Math.floor(roundStartTime / 1000),
      JSON.stringify(questionIds),
      'active'
    ).run();
    // Re-fetch in case another request won the race
    round = await env.DB.prepare('SELECT * FROM rounds WHERE id = ?').bind(roundId).first();
  }
  return round;
}

// NEW: Get current live state (primary endpoint for live trivia)
async function handleGetLiveState(env, corsHeaders) {
  const now = Date.now();

  // Calculate which round we're in (rounds every 250 seconds)
  const roundStartTime = Math.floor(now / (ROUND_DURATION * 1000)) * (ROUND_DURATION * 1000);
  const elapsedInRound = (now - roundStartTime) / 1000; // seconds since round started

  // Generate round ID from timestamp
  const date = new Date(roundStartTime);
  const roundId = `round_${date.toISOString().slice(0, 19).replace('T', '_').replace(/:/g, '-')}`;

  // Ensure round exists in database
  const round = await getOrCreateRound(roundId, roundStartTime, env);
  const questionIds = JSON.parse(round.question_ids);

  // Calculate current state based on elapsed time
  let phase, currentQuestionIndex, secondsRemaining, nextRoundStartsIn;

  if (elapsedInRound < QUIZ_DURATION) {
    // We're in the quiz phase (questions 1-10)
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

  // Get active player count with 10-second cache
  if (now - cachedPlayerCount.fetchedAt > 10_000) {
    const playerCountResult = await env.DB.prepare(`
      SELECT COUNT(DISTINCT user_id) as count
      FROM scores
      WHERE submitted_at > unixepoch() - 300
    `).first();
    cachedPlayerCount = { count: playerCountResult?.count || 0, fetchedAt: now };
  }

  return jsonResponse({
    roundId,
    currentQuestionIndex,
    phase,
    secondsRemaining,
    questionIds,
    nextRoundStartsIn,
    activePlayerCount: cachedPlayerCount.count,
    roundStartTime: roundStartTime,
  }, 200, corsHeaders);
}

// Get current active round (legacy endpoint - kept for compatibility)
async function handleGetCurrentRound(env, corsHeaders) {
  const now = Date.now();
  const roundStartTime = Math.floor(now / (ROUND_DURATION * 1000)) * (ROUND_DURATION * 1000);
  const date = new Date(roundStartTime);
  const roundId = `round_${date.toISOString().slice(0, 19).replace('T', '_').replace(/:/g, '-')}`;

  const round = await getOrCreateRound(roundId, roundStartTime, env);

  return jsonResponse({
    id: round.id,
    startTime: round.start_time * 1000,
    questionIds: JSON.parse(round.question_ids),
    status: round.status,
  }, 200, corsHeaders);
}

// Get specific round by ID
async function handleGetRound(roundId, env, corsHeaders) {
  const round = await env.DB.prepare(
    'SELECT * FROM rounds WHERE id = ?'
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

// Submit score for a round
async function handleSubmitScore(request, roundId, env, corsHeaders) {
  let body;
  try { body = await request.json(); } catch { return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders); }
  
  // Validate required fields
  if (!body.userId || !body.username || body.score === undefined || body.completionTime === undefined) {
    return jsonResponse({
      error: 'Missing required fields: userId, username, score, completionTime'
    }, 400, corsHeaders);
  }

  // Validate field types and ranges
  if (typeof body.userId !== 'string' || body.userId.length > 100) {
    return jsonResponse({ error: 'Invalid userId' }, 400, corsHeaders);
  }
  if (typeof body.username !== 'string' || body.username.length < 1 || body.username.length > 50) {
    return jsonResponse({ error: 'Invalid username (1-50 characters)' }, 400, corsHeaders);
  }
  if (!/^[a-zA-Z0-9\s\-_.]+$/.test(body.username)) {
    return jsonResponse({ error: 'Username contains invalid characters' }, 400, corsHeaders);
  }
  if (typeof body.score !== 'number' || !Number.isFinite(body.score) || body.score < 0 || body.score > 10000) {
    return jsonResponse({ error: 'Invalid score (0-10000)' }, 400, corsHeaders);
  }
  if (typeof body.completionTime !== 'number' || !Number.isFinite(body.completionTime) || body.completionTime < 0 || body.completionTime > 300) {
    return jsonResponse({ error: 'Invalid completionTime (0-300)' }, 400, corsHeaders);
  }

  // Verify round exists and is within submission window
  const round = await env.DB.prepare(
    'SELECT id, start_time FROM rounds WHERE id = ?'
  ).bind(roundId).first();

  if (!round) {
    return jsonResponse({ error: 'Round not found' }, 404, corsHeaders);
  }

  // Reject submissions for rounds older than 10 minutes
  const nowUnix = Math.floor(Date.now() / 1000);
  const roundAge = nowUnix - round.start_time;
  if (roundAge > 600) {
    return jsonResponse({ error: 'Round expired — submissions are closed' }, 400, corsHeaders);
  }

  // First submission wins — reject duplicates
  const existing = await env.DB.prepare(
    'SELECT score FROM scores WHERE round_id = ? AND user_id = ?'
  ).bind(roundId, body.userId).first();

  if (existing) {
    // Return existing score instead of allowing update
    const existingRank = await env.DB.prepare(`
      SELECT COUNT(*) + 1 as rank FROM scores
      WHERE round_id = ? AND (score > ? OR (score = ? AND completion_time < ?))
    `).bind(roundId, existing.score, existing.score, Math.floor(body.completionTime)).first();
    return jsonResponse({
      success: true,
      rank: existingRank.rank,
      score: existing.score,
      duplicate: true,
    }, 200, corsHeaders);
  }

  // Insert score (no upsert — first submission only)
  await env.DB.prepare(`
    INSERT INTO scores (round_id, user_id, username, score, completion_time)
    VALUES (?, ?, ?, ?, ?)
  `).bind(
    roundId,
    body.userId,
    body.username,
    body.score,
    Math.floor(body.completionTime)
  ).run();

  // Update username on all past scores for this user (in case they changed it)
  await env.DB.prepare(`
    UPDATE scores SET username = ? WHERE user_id = ? AND username != ?
  `).bind(body.username, body.userId, body.username).run();

  // Get user's rank
  const rankResult = await env.DB.prepare(`
    SELECT COUNT(*) + 1 as rank
    FROM scores
    WHERE round_id = ? AND (
      score > ? OR
      (score = ? AND completion_time < ?)
    )
  `).bind(roundId, body.score, body.score, Math.floor(body.completionTime)).first();
  
  return jsonResponse({
    success: true,
    rank: rankResult.rank,
    score: body.score,
  }, 200, corsHeaders);
}

// Get daily leaderboard (top 10 by total score in last 24 hours)
async function handleGetDailyLeaderboard(env, corsHeaders) {
  const results = await env.DB.prepare(`
    SELECT s.user_id,
           lu.username,
           SUM(s.score) as total_score,
           COUNT(*) as rounds_played
    FROM scores s
    JOIN (
      SELECT user_id, username
      FROM scores
      WHERE (user_id, submitted_at) IN (
        SELECT user_id, MAX(submitted_at) FROM scores GROUP BY user_id
      )
    ) lu ON lu.user_id = s.user_id
    WHERE s.submitted_at > unixepoch() - 86400
    GROUP BY s.user_id
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

// Get leaderboard for a round
async function handleGetLeaderboard(roundId, env, corsHeaders) {
  // Get top 100 scores
  const results = await env.DB.prepare(`
    SELECT 
      user_id,
      username,
      score,
      completion_time,
      submitted_at
    FROM scores
    WHERE round_id = ?
    ORDER BY score DESC, completion_time ASC
    LIMIT 100
  `).bind(roundId).all();
  
  if (!results.success) {
    return jsonResponse({ error: 'Failed to fetch leaderboard' }, 500, corsHeaders);
  }
  
  // Add rank to each entry
  const leaderboard = results.results.map((entry, index) => ({
    rank: index + 1,
    userId: entry.user_id,
    username: entry.username,
    score: entry.score,
    completionTime: entry.completion_time,
    submittedAt: entry.submitted_at * 1000, // Convert to JS timestamp
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

// Get user statistics across all rounds
async function handleGetUserStats(userId, env, corsHeaders) {
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
  
  // Get best rank using window function (no correlated subquery)
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

// Get full question objects by IDs
async function handleGetQuestions(request, env, corsHeaders) {
  let body;
  try { body = await request.json(); } catch { return jsonResponse({ error: 'Invalid JSON body' }, 400, corsHeaders); }
  
  if (!body.ids || !Array.isArray(body.ids) || body.ids.length === 0 || body.ids.length > 50) {
    return jsonResponse({ error: 'ids array must contain 1-50 items' }, 400, corsHeaders);
  }

  // Validate each ID is a string
  if (!body.ids.every(id => typeof id === 'string' && id.length <= 50)) {
    return jsonResponse({ error: 'Invalid question ID format' }, 400, corsHeaders);
  }

  // Build placeholders for SQL
  const placeholders = body.ids.map(() => '?').join(',');
  
  const results = await env.DB.prepare(`
    SELECT * FROM questions WHERE id IN (${placeholders})
  `).bind(...body.ids).all();
  
  if (!results.success) {
    return jsonResponse({ error: 'Failed to fetch questions' }, 500, corsHeaders);
  }
  
  // Parse JSON fields and format for iOS (with error handling)
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
      choices: choices,
      correctIndex: q.correct_index,
      explanation: q.explanation || ''
    };
  });
  
  return jsonResponse({ questions }, 200, {
    ...corsHeaders,
    'Cache-Control': 'public, max-age=3600',
  });
}

// Delete all data associated with a user (GDPR/CCPA right to erasure)
async function handleDeleteUser(userId, env, corsHeaders) {
  await env.DB.prepare('DELETE FROM scores WHERE user_id = ?').bind(userId).run();
  await env.DB.prepare('DELETE FROM attestations WHERE device_id = ?').bind(userId).run();
  return jsonResponse({ success: true }, 200, corsHeaders);
}

// Helper: Select random questions from database, avoiding recent repeats
async function selectRandomQuestions(db, count) {
  // Look back 30 rounds (~2 hours) to avoid repeating questions
  const LOOKBACK_ROUNDS = 30;

  const recentRounds = await db.prepare(`
    SELECT question_ids FROM rounds
    ORDER BY start_time DESC
    LIMIT ?
  `).bind(LOOKBACK_ROUNDS).all();

  // Collect all recently used question IDs
  const usedIds = new Set();
  if (recentRounds.success) {
    for (const row of recentRounds.results) {
      try {
        const ids = JSON.parse(row.question_ids);
        for (const id of ids) usedIds.add(id);
      } catch { /* skip malformed rows */ }
    }
  }

  // Try to select only from unused questions
  if (usedIds.size > 0) {
    const placeholders = Array.from(usedIds).map(() => '?').join(',');
    const result = await db.prepare(`
      SELECT id FROM questions
      WHERE id NOT IN (${placeholders})
      ORDER BY RANDOM()
      LIMIT ?
    `).bind(...usedIds, count).all();

    if (result.success && result.results.length >= count) {
      return result.results.map(row => row.id);
    }
  }

  // Fallback: not enough unused questions — pull from full pool
  const result = await db.prepare(`
    SELECT id FROM questions ORDER BY RANDOM() LIMIT ?
  `).bind(count).all();

  if (!result.success || result.results.length === 0) {
    throw new Error('No questions available in database');
  }

  return result.results.map(row => row.id);
}
