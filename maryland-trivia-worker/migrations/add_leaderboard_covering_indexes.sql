-- Covering indexes for high-traffic leaderboard and user-history reads.
CREATE INDEX IF NOT EXISTS idx_scores_daily_user_score
  ON scores(submitted_at DESC, user_id, username, score);

CREATE INDEX IF NOT EXISTS idx_scores_user_round
  ON scores(user_id, round_id, score DESC, completion_time ASC);
