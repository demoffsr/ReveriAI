-- One-time cleanup: remove rate limit records from debug testing
-- Safe to re-run (idempotent DELETE)
DELETE FROM rate_limits WHERE function_name = 'register-analytics';
