-- Refresh token rotation support.
-- Stores the current valid refresh token's jti (JWT ID) so old tokens
-- are rejected after a new one is issued.
ALTER TABLE attestations ADD COLUMN last_refresh_jti TEXT;
