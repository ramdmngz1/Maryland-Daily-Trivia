-- Initial schema for Maryland Daily Trivia.
-- Applied manually at database creation; included here as the
-- single source of truth for the core table definitions.

CREATE TABLE IF NOT EXISTS questions (
  id            TEXT PRIMARY KEY,
  category      TEXT    NOT NULL,
  difficulty    TEXT    NOT NULL,
  question      TEXT    NOT NULL,
  choices       TEXT    NOT NULL,   -- JSON array of strings
  correct_index INTEGER NOT NULL,
  explanation   TEXT    NOT NULL,
  image_url     TEXT
);

CREATE TABLE IF NOT EXISTS rounds (
  id           TEXT    PRIMARY KEY,
  start_time   INTEGER NOT NULL,   -- Unix epoch seconds
  question_ids TEXT    NOT NULL,   -- JSON array of question IDs
  status       TEXT    NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS scores (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  round_id        TEXT    NOT NULL,
  user_id         TEXT    NOT NULL,
  username        TEXT    NOT NULL,
  score           INTEGER NOT NULL,
  completion_time INTEGER NOT NULL,
  submitted_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS attestations (
  device_id     TEXT PRIMARY KEY,
  key_id        TEXT    NOT NULL,
  attested_at   INTEGER NOT NULL,
  last_token_at INTEGER NOT NULL,
  revoked       INTEGER NOT NULL DEFAULT 0
);
