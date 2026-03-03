-- Fix: "column reference window_duration_seconds is ambiguous" in check_rate_limits
-- RETURNS TABLE output columns (window_duration_seconds, current_count) share names
-- with rate_limits table columns. #variable_conflict use_column tells plpgsql to
-- prefer table columns in SQL statements; := assignments always target variables.
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
#variable_conflict use_column
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

    v_window_start := to_timestamp(
      floor(extract(epoch FROM now()) / v_duration) * v_duration
    );

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
