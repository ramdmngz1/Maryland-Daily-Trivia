import { CHALLENGE_TTL_SECONDS, ACCESS_TOKEN_TTL, REFRESH_TOKEN_TTL } from './constants.js';

const TOKEN_ISSUER = 'maryland-trivia-worker';

// ── Base64url helpers ──

function base64url(buf) {
  const bytes = buf instanceof ArrayBuffer ? new Uint8Array(buf) : buf;
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function base64urlDecode(str) {
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

// ── JWT (HS256) ──

export async function createJWT(payload, secret) {
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

export async function verifyJWT(token, secret) {
  if (typeof token !== 'string' || token.length > 4096) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const enc = new TextEncoder();
  try {
    const header = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[0])));
    if (header.alg !== 'HS256' || header.typ !== 'JWT') return null;

    const key = await crypto.subtle.importKey(
      'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']
    );
    const valid = await crypto.subtle.verify(
      'HMAC', key, base64urlDecode(parts[2]), enc.encode(parts[0] + '.' + parts[1])
    );
    if (!valid) return null;

    const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(parts[1])));
    const now = Math.floor(Date.now() / 1000);
    if (payload.iss !== TOKEN_ISSUER) return null;
    if (typeof payload.sub !== 'string' || !payload.sub) return null;
    if (!['access', 'refresh'].includes(payload.type)) return null;
    if (typeof payload.exp !== 'number' || payload.exp < now) return null;
    if (payload.nbf && payload.nbf > now) return null;
    return payload;
  } catch {
    return null;
  }
}

export async function issueTokens(deviceId, env) {
  const now = Math.floor(Date.now() / 1000);
  const refreshJti = crypto.randomUUID();
  const accessToken = await createJWT(
    { sub: deviceId, iat: now, exp: now + ACCESS_TOKEN_TTL, iss: TOKEN_ISSUER, type: 'access' },
    env.JWT_SECRET
  );
  const refreshToken = await createJWT(
    { sub: deviceId, iat: now, exp: now + REFRESH_TOKEN_TTL, iss: TOKEN_ISSUER, type: 'refresh', jti: refreshJti },
    env.JWT_SECRET
  );
  return { accessToken, refreshToken, expiresIn: ACCESS_TOKEN_TTL, refreshJti };
}

export async function authenticateRequest(request, env) {
  const authHeader = request.headers.get('Authorization');
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    const payload = await verifyJWT(token, env.JWT_SECRET);
    if (payload && payload.type === 'access') {
      const device = await env.DB.prepare(
        'SELECT revoked FROM attestations WHERE device_id = ?'
      ).bind(payload.sub).first();
      if (!device || device.revoked) return null;
      return payload;
    }
  }
  return null;
}

// ── Attestation verification ──

export async function verifyAndroidChallengeSignature({ challengeNonce, deviceId, keyId, attestation, publicKey }) {
  if (!challengeNonce || !deviceId || !keyId || !attestation || !publicKey) return false;
  let publicKeyBytes, signatureBytes;
  try {
    publicKeyBytes = base64urlDecode(publicKey);
    signatureBytes = base64urlDecode(attestation);
  } catch { return false; }

  const expectedKeyId = `android_${await sha256Base64Url(publicKeyBytes)}`;
  if (expectedKeyId !== keyId) return false;

  let cryptoKey;
  try {
    cryptoKey = await crypto.subtle.importKey(
      'spki', toArrayBuffer(publicKeyBytes),
      { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']
    );
  } catch { return false; }

  const payload = `${challengeNonce}:${deviceId}:${keyId}`;
  return crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' }, cryptoKey,
    toArrayBuffer(signatureBytes), new TextEncoder().encode(payload)
  );
}

// ── CBOR decoder (minimal — Apple attestation only) ──

function cborDecode(bytes) {
  if (!(bytes instanceof Uint8Array)) bytes = new Uint8Array(bytes);
  let pos = 0;
  function u8()  { return bytes[pos++]; }
  function u16() { const v = (bytes[pos] << 8) | bytes[pos + 1]; pos += 2; return v >>> 0; }
  function u32() {
    const v = ((bytes[pos] << 24) | (bytes[pos+1] << 16) | (bytes[pos+2] << 8) | bytes[pos+3]) >>> 0;
    pos += 4; return v;
  }
  function readLen(add) {
    if (add < 24) return add;
    if (add === 24) return u8();
    if (add === 25) return u16();
    if (add === 26) return u32();
    throw new Error('cbor: unsupported length encoding');
  }
  function decode() {
    const b = u8(), major = b >> 5, add = b & 0x1f, len = readLen(add);
    switch (major) {
      case 0: return len;
      case 2: { const s = bytes.slice(pos, pos + len); pos += len; return s; }
      case 3: { const s = bytes.slice(pos, pos + len); pos += len; return new TextDecoder().decode(s); }
      case 4: { const a = []; for (let i = 0; i < len; i++) a.push(decode()); return a; }
      case 5: { const m = {}; for (let i = 0; i < len; i++) { const k = decode(); m[k] = decode(); } return m; }
      default: throw new Error(`cbor: unsupported major type ${major}`);
    }
  }
  return decode();
}

export async function verifyiOSAttestationNonce(challengeNonce, attestation) {
  try {
    const attBytes = base64urlDecode(attestation);
    const attObj = cborDecode(attBytes);
    if (attObj.fmt !== 'apple-appattest') return false;

    const authData = attObj.authData;
    const x5c = attObj.attStmt && attObj.attStmt.x5c;
    if (!authData || !x5c || !x5c[0]) return false;

    const leafCert = x5c[0] instanceof Uint8Array ? x5c[0] : new Uint8Array(x5c[0]);
    const enc = new TextEncoder();
    const clientDataHash = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(challengeNonce)));

    const combined = new Uint8Array(authData.length + clientDataHash.length);
    combined.set(authData, 0);
    combined.set(clientDataHash, authData.length);
    const expectedNonce = new Uint8Array(await crypto.subtle.digest('SHA-256', combined));

    for (let i = 0; i <= leafCert.length - 32; i++) {
      let ok = true;
      for (let j = 0; j < 32; j++) {
        if (leafCert[i + j] !== expectedNonce[j]) { ok = false; break; }
      }
      if (ok) return true;
    }
    return false;
  } catch { return false; }
}

// ── D1-backed challenge store ──

export async function issueChallenge(deviceId, env) {
  const buf = new Uint8Array(32);
  crypto.getRandomValues(buf);
  const nonce = Array.from(buf).map(b => b.toString(16).padStart(2, '0')).join('');
  const now = Math.floor(Date.now() / 1000);

  await env.DB.prepare(`
    INSERT INTO challenges (device_id, nonce, created_at)
    VALUES (?, ?, ?)
    ON CONFLICT(device_id) DO UPDATE SET nonce = excluded.nonce, created_at = excluded.created_at
  `).bind(deviceId, nonce, now).run();

  env.DB.prepare('DELETE FROM challenges WHERE created_at < ?')
    .bind(now - CHALLENGE_TTL_SECONDS).run().catch(() => {});

  return nonce;
}

export async function consumeChallenge(deviceId, env) {
  const now = Math.floor(Date.now() / 1000);
  const row = await env.DB.prepare(
    'SELECT nonce FROM challenges WHERE device_id = ? AND created_at >= ?'
  ).bind(deviceId, now - CHALLENGE_TTL_SECONDS).first();

  if (!row) return null;
  await env.DB.prepare('DELETE FROM challenges WHERE device_id = ?').bind(deviceId).run();
  return row.nonce;
}

// ── Shared attestation upsert ──

export async function upsertAttestation(env, deviceId, keyId, refreshJti = null) {
  await env.DB.prepare(`
    INSERT INTO attestations (device_id, key_id, attested_at, last_token_at, revoked, last_refresh_jti)
    VALUES (?, ?, unixepoch(), unixepoch(), 0, ?)
    ON CONFLICT(device_id) DO UPDATE SET key_id = ?, last_token_at = unixepoch(), last_refresh_jti = ?
  `).bind(deviceId, keyId, refreshJti, keyId, refreshJti).run();
}
