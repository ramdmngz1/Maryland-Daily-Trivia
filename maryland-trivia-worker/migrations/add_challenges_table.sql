-- Migration: replace in-memory challenge nonce store with D1-backed table.
-- Challenges must survive across Cloudflare Worker isolates so that a
-- challenge issued on one edge node can be verified on a different one.

CREATE TABLE IF NOT EXISTS challenges (
  device_id  TEXT    PRIMARY KEY,
  nonce      TEXT    NOT NULL,
  created_at INTEGER NOT NULL   -- Unix epoch seconds
);

CREATE INDEX IF NOT EXISTS idx_challenges_created_at ON challenges(created_at);
