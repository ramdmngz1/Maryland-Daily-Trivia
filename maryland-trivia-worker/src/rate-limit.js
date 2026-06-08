import { RATE_LIMIT_WINDOW_MS, RATE_LIMIT_MAX_REQUESTS } from './constants.js';

const rateLimitMap = new Map();
let lastPruneTime = 0;
const PRUNE_INTERVAL_MS = 30_000;

const KV_BACKED_BUCKETS = new Set(['auth', 'write', 'questions']);

export function rateLimitBucketFor(pathname, method) {
  if (pathname === '/api/live-state') return 'liveState';
  if (pathname.startsWith('/api/leaderboard/')) return 'leaderboard';
  if (pathname.startsWith('/auth/')) return 'auth';
  if (pathname === '/api/questions') return 'questions';
  if (method === 'POST' && pathname.match(/^\/api\/rounds\/[^/]+\/score$/)) return 'write';
  if (method === 'DELETE' && pathname.match(/^\/api\/user\/[^/]+$/)) return 'write';
  return 'default';
}

export async function checkRateLimit(ip, bucket, maxRequests, env) {
  if (env.RATE_LIMITS && KV_BACKED_BUCKETS.has(bucket)) {
    return checkRateLimitGlobal(ip, bucket, maxRequests, env.RATE_LIMITS);
  }
  return checkRateLimitInMemory(ip, bucket, maxRequests, Date.now());
}

async function checkRateLimitGlobal(ip, bucket, maxRequests, kvNamespace) {
  const now = Date.now();
  const key = `rl:${ip}:${bucket}`;

  try {
    const raw = await kvNamespace.get(key);
    const entry = raw ? JSON.parse(raw) : null;

    if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW_MS) {
      await kvNamespace.put(key, JSON.stringify({ windowStart: now, count: 1 }), { expirationTtl: 120 });
      return { limited: false, retryAfter: 0 };
    }

    const newCount = entry.count + 1;
    await kvNamespace.put(key, JSON.stringify({ windowStart: entry.windowStart, count: newCount }), { expirationTtl: 120 });

    if (newCount > maxRequests) {
      const retryAfter = Math.max(1, Math.ceil((entry.windowStart + RATE_LIMIT_WINDOW_MS - now) / 1000));
      return { limited: true, retryAfter };
    }
    return { limited: false, retryAfter: 0 };
  } catch {
    return checkRateLimitInMemory(ip, bucket, maxRequests, now);
  }
}

function checkRateLimitInMemory(ip, bucket, maxRequests, now) {
  if (now - lastPruneTime > PRUNE_INTERVAL_MS) {
    lastPruneTime = now;
    for (const [k, v] of rateLimitMap) {
      if (now - v.windowStart > RATE_LIMIT_WINDOW_MS) rateLimitMap.delete(k);
    }
  }

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
