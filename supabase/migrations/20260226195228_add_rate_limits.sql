-- Rate limiting table for edge functions
-- Stores per-user and per-IP request counts with sliding windows
CREATE TABLE IF NOT EXISTS rate_limits (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  identifier TEXT NOT NULL,           -- user_id or 'ip:1.2.3.4'
  function_name TEXT NOT NULL,
  window_start TIMESTAMPTZ NOT NULL,
  window_duration_seconds INT NOT NULL,
  request_count INT NOT NULL DEFAULT 1,
  UNIQUE (identifier, function_name, window_start, window_duration_seconds)
);

-- Index for cleanup queries
CREATE INDEX idx_rate_limits_window_start ON rate_limits (window_start);

-- Atomic rate limit check: increments counters and returns whether any limit is exceeded
-- p_windows: [{"duration_seconds": 60, "max_requests": 5}, ...]
CREATE OR REPLACE FUNCTION check_rate_limits(
  p_identifier TEXT,
  p_function_name TEXT,
  p_windows JSONB
)
RETURNS TABLE (
  window_duration_seconds INT,
  current_count INT,
  max_requests INT,
  is_exceeded BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  w JSONB;
  v_duration INT;
  v_max INT;
  v_window_start TIMESTAMPTZ;
  v_count INT;
BEGIN
  FOR w IN SELECT * FROM jsonb_array_elements(p_windows)
  LOOP
    v_duration := (w->>'duration_seconds')::INT;
    v_max := (w->>'max_requests')::INT;

    -- Align window start to fixed intervals for predictable behavior
    v_window_start := to_timestamp(
      floor(extract(epoch FROM now()) / v_duration) * v_duration
    );

    -- Atomic upsert: insert or increment
    INSERT INTO rate_limits (identifier, function_name, window_start, window_duration_seconds, request_count)
    VALUES (p_identifier, p_function_name, v_window_start, v_duration, 1)
    ON CONFLICT (identifier, function_name, window_start, window_duration_seconds)
    DO UPDATE SET request_count = rate_limits.request_count + 1
    RETURNING rate_limits.request_count INTO v_count;

    window_duration_seconds := v_duration;
    current_count := v_count;
    max_requests := v_max;
    is_exceeded := v_count > v_max;
    RETURN NEXT;
  END LOOP;
END;
$$;

-- Cleanup function: removes expired rate limit entries (older than 48 hours)
CREATE OR REPLACE FUNCTION cleanup_rate_limits()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM rate_limits
  WHERE window_start < now() - interval '48 hours';
END;
$$;

-- Cleanup relies on probabilistic trigger (1% of requests) in rate-limit.ts
-- To enable pg_cron: enable the extension in Supabase Dashboard → Database → Extensions,
-- then run: SELECT cron.schedule('cleanup-rate-limits', '0 4 * * *', 'SELECT cleanup_rate_limits()');
