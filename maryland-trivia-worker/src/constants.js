export const QUESTION_TIME = 12;
export const EXPLANATION_TIME = 10;
export const RESULTS_TIME = 10;
export const LEADERBOARD_TIME = 20;
export const QUESTIONS_PER_ROUND = 10;
export const QUESTION_CYCLE = QUESTION_TIME + EXPLANATION_TIME;
export const QUIZ_DURATION = QUESTION_CYCLE * QUESTIONS_PER_ROUND;
export const ROUND_DURATION = QUIZ_DURATION + RESULTS_TIME + LEADERBOARD_TIME;

export const CHALLENGE_TTL_SECONDS = 60;
export const ACCESS_TOKEN_TTL = 3600;
export const REFRESH_TOKEN_TTL = 30 * 86400;
export const SCORE_SUBMISSION_WINDOW = 600;
export const MAX_COMPLETION_TIME = 300;
export const MAX_DEVICE_ID_LENGTH = 200;
export const MAX_USER_ID_LENGTH = 100;
export const USERNAME_MAX_LENGTH = 20;
export const MAX_QUESTION_IDS_PER_REQUEST = 50;
export const MAX_JSON_BODY_BYTES = 64 * 1024;
export const LOOKBACK_ROUNDS = 20;

export const RATE_LIMIT_WINDOW_MS = 60_000;
export const RATE_LIMIT_MAX_REQUESTS = {
  default: 60,
  liveState: 90,
  leaderboard: 30,
  auth: 10,
  write: 30,
  questions: 40,
};

export const ROUND_ID_REGEX = /^round_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/;
export const DEVICE_ID_REGEX = /^device_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const QUESTION_ID_REGEX = /^[a-z0-9_]{1,50}$/i;
export const USERNAME_BLOCKLIST_REGEX = /\b(?:asshole|bitch|cunt|dick|fag|fuck|hitler|nazi|nigger|porn|sex|shit|slut|whore|xxx)\b/i;
