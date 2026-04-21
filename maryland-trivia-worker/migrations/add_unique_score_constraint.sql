-- Enforce one score per user per round at the database level.
-- Replaces the non-unique idx_scores_round_user index.
DROP INDEX IF EXISTS idx_scores_round_user;
CREATE UNIQUE INDEX IF NOT EXISTS idx_scores_round_user ON scores(round_id, user_id);
