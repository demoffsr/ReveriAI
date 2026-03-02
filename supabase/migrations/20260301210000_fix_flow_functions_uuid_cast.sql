-- Fix UUID vs TEXT comparison errors in flow analysis functions
-- session_id column is UUID, but some comparisons used text without casting

-- 1. Fix analytics_funnel: cast session_id to text for comparison
CREATE OR REPLACE FUNCTION analytics_funnel(p_steps text[], p_hours int DEFAULT 24)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  cutoff timestamptz := now() - (p_hours || ' hours')::interval;
  total_sessions bigint;
BEGIN
  -- Count total unique sessions in the time window
  SELECT count(DISTINCT session_id) INTO total_sessions
  FROM app_events
  WHERE created_at >= cutoff;

  -- Build funnel: for each step, count sessions that have ALL previous steps + this step
  WITH step_list AS (
    SELECT ordinality AS step_num, step_name
    FROM unnest(p_steps) WITH ORDINALITY AS t(step_name, ordinality)
  ),
  session_steps AS (
    SELECT DISTINCT session_id::text AS sid, event_type
    FROM app_events
    WHERE created_at >= cutoff
      AND event_type = ANY(p_steps)
  ),
  funnel AS (
    SELECT
      sl.step_num,
      sl.step_name AS event,
      count(DISTINCT ss.sid) AS sessions
    FROM step_list sl
    CROSS JOIN (SELECT DISTINCT sid FROM session_steps) all_sessions
    JOIN LATERAL (
      SELECT ss2.sid
      FROM session_steps ss2
      WHERE ss2.sid = all_sessions.sid
        AND ss2.event_type = sl.step_name
    ) ss ON true
    WHERE NOT EXISTS (
      -- Check that all PREVIOUS steps also exist for this session
      SELECT 1 FROM step_list prev
      WHERE prev.step_num < sl.step_num
        AND NOT EXISTS (
          SELECT 1 FROM session_steps ss3
          WHERE ss3.sid = all_sessions.sid
            AND ss3.event_type = prev.step_name
        )
    )
    GROUP BY sl.step_num, sl.step_name
    ORDER BY sl.step_num
  )
  SELECT json_build_object(
    'total_sessions', total_sessions,
    'steps', COALESCE(
      (SELECT json_agg(json_build_object(
        'step', f.step_num,
        'event', f.event,
        'sessions', f.sessions,
        'rate_pct', CASE WHEN total_sessions > 0
          THEN round((f.sessions::numeric / total_sessions * 100)::numeric, 1)
          ELSE 0 END,
        'drop_off_pct', CASE
          WHEN f.step_num = 1 THEN 0
          ELSE round((1 - f.sessions::numeric / GREATEST(
            (SELECT f2.sessions FROM funnel f2 WHERE f2.step_num = f.step_num - 1), 1
          )) * 100, 1)
          END
      ) ORDER BY f.step_num) FROM funnel f),
      '[]'::json
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- 2. Fix analytics_user_flow: accept uuid parameter or cast text to uuid
CREATE OR REPLACE FUNCTION analytics_user_flow(p_session_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  session_uuid uuid;
BEGIN
  -- Cast text to uuid
  BEGIN
    session_uuid := p_session_id::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN json_build_object('error', 'Invalid session_id format');
  END;

  WITH ordered_events AS (
    SELECT
      event_type,
      metadata,
      created_at,
      LAG(created_at) OVER (ORDER BY created_at) AS prev_at
    FROM app_events
    WHERE session_id = session_uuid
    ORDER BY created_at
  )
  SELECT COALESCE(
    json_agg(json_build_object(
      'event_type', event_type,
      'metadata', metadata,
      'created_at', created_at,
      'gap_sec', COALESCE(
        EXTRACT(EPOCH FROM (created_at - prev_at))::numeric,
        0
      )
    ) ORDER BY created_at),
    '[]'::json
  ) INTO result
  FROM ordered_events;

  RETURN result;
END;
$$;

-- Restrict to service_role only (called via edge functions)
REVOKE ALL ON FUNCTION analytics_funnel(text[], int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics_funnel(text[], int) TO service_role;
REVOKE ALL ON FUNCTION analytics_user_flow(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics_user_flow(text) TO service_role;
