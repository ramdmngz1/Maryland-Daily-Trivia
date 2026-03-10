-- Performance indexes for scores table
CREATE INDEX IF NOT EXISTS idx_scores_user_id ON scores(user_id);
CREATE INDEX IF NOT EXISTS idx_scores_round_id ON scores(round_id);
CREATE INDEX IF NOT EXISTS idx_scores_submitted_at ON scores(submitted_at);
CREATE INDEX IF NOT EXISTS idx_scores_round_user ON scores(round_id, user_id);
CREATE INDEX IF NOT EXISTS idx_scores_round_score ON scores(round_id, score DESC, completion_time ASC);
