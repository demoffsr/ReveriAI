-- Per-User Analytics: 3 functions for user list, profile, and event log
-- Enables drill-down into individual user activity from the dashboard

-- ============================================================
-- 1. User List (paginated, with key metrics)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_user_list(
  p_days int DEFAULT 30,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  cutoff timestamptz := now() - (p_days || ' days')::interval;
BEGIN
  WITH user_stats AS (
    SELECT
      user_id,
      min(created_at) AS first_seen,
      max(created_at) AS last_seen,
      count(*)::int AS total_events,
      count(DISTINCT session_id)::int AS total_sessions
    FROM app_events
    WHERE created_at >= cutoff
    GROUP BY user_id
  ),
  dream_counts AS (
    SELECT user_id, count(*)::int AS total_dreams
    FROM app_events
    WHERE created_at >= cutoff
      AND event_type IN ('dream_recorded', 'review_saved_audio')
    GROUP BY user_id
  ),
  last_events AS (
    SELECT DISTINCT ON (user_id)
      user_id, event_type AS last_event_type
    FROM app_events
    WHERE created_at >= cutoff
    ORDER BY user_id, created_at DESC
  ),
  device_mode AS (
    SELECT DISTINCT ON (user_id)
      user_id, device
    FROM (
      SELECT user_id, device, count(*) AS cnt
      FROM app_events
      WHERE created_at >= cutoff AND device IS NOT NULL
      GROUP BY user_id, device
    ) sub
    ORDER BY user_id, cnt DESC
  ),
  combined AS (
    SELECT
      us.user_id,
      left(us.user_id::text, 8) AS user_id_short,
      us.first_seen,
      us.last_seen,
      us.total_events,
      us.total_sessions,
      COALESCE(dc.total_dreams, 0) AS total_dreams,
      le.last_event_type,
      dm.device,
      count(*) OVER()::int AS total_count
    FROM user_stats us
    LEFT JOIN dream_counts dc ON us.user_id = dc.user_id
    LEFT JOIN last_events le ON us.user_id = le.user_id
    LEFT JOIN device_mode dm ON us.user_id = dm.user_id
    ORDER BY us.last_seen DESC
    LIMIT p_limit OFFSET p_offset
  )
  SELECT json_build_object(
    'users', COALESCE(
      (SELECT json_agg(json_build_object(
        'user_id', c.user_id,
        'user_id_short', c.user_id_short,
        'first_seen', c.first_seen,
        'last_seen', c.last_seen,
        'total_events', c.total_events,
        'total_sessions', c.total_sessions,
        'total_dreams', c.total_dreams,
        'last_event_type', c.last_event_type,
        'device', c.device
      ) ORDER BY c.last_seen DESC) FROM combined c),
      '[]'::json
    ),
    'total', COALESCE((SELECT total_count FROM combined LIMIT 1), 0)
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- 2. User Profile (detailed stats for one user)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_user_profile(p_user_id text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  user_uuid uuid;
BEGIN
  -- Safe UUID cast
  BEGIN
    user_uuid := p_user_id::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN json_build_object('error', 'Invalid user_id format');
  END;

  WITH basics AS (
    SELECT
      min(created_at) AS first_seen,
      max(created_at) AS last_seen,
      count(*)::int AS total_events,
      count(DISTINCT session_id)::int AS total_sessions
    FROM app_events
    WHERE user_id = user_uuid
  ),
  dream_stats AS (
    SELECT
      count(*)::int AS total_dreams,
      count(*) FILTER (WHERE event_type = 'review_saved_audio')::int AS voice_dreams,
      count(*) FILTER (WHERE event_type = 'dream_recorded'
        AND (metadata->>'mode') = 'text')::int AS text_dreams
    FROM app_events
    WHERE user_id = user_uuid
      AND event_type IN ('dream_recorded', 'review_saved_audio')
  ),
  emotions AS (
    SELECT emotion, count(*)::int AS cnt
    FROM app_events,
      jsonb_array_elements_text(COALESCE(metadata->'emotions', '[]'::jsonb)) AS emotion
    WHERE user_id = user_uuid
      AND event_type IN ('dream_recorded', 'review_saved_audio')
      AND metadata ? 'emotions'
    GROUP BY emotion
    ORDER BY cnt DESC
    LIMIT 5
  ),
  ai_usage AS (
    SELECT
      count(*) FILTER (WHERE event_type = 'ai_title_completed')::int AS titles,
      count(*) FILTER (WHERE event_type = 'ai_image_completed')::int AS images,
      count(*) FILTER (WHERE event_type = 'ai_interpretation_completed')::int AS interpretations
    FROM app_events
    WHERE user_id = user_uuid
  ),
  active_hour AS (
    SELECT EXTRACT(HOUR FROM created_at)::int AS hour
    FROM app_events
    WHERE user_id = user_uuid
    GROUP BY 1
    ORDER BY count(*) DESC
    LIMIT 1
  ),
  devices AS (
    SELECT device, count(*)::int AS cnt
    FROM app_events
    WHERE user_id = user_uuid AND device IS NOT NULL
    GROUP BY device
    ORDER BY cnt DESC
  ),
  events_by_day AS (
    SELECT
      date_trunc('day', created_at)::date AS day,
      count(*)::int AS cnt
    FROM app_events
    WHERE user_id = user_uuid
      AND created_at >= now() - interval '30 days'
    GROUP BY 1
    ORDER BY 1
  ),
  event_breakdown AS (
    SELECT event_type, count(*)::int AS cnt
    FROM app_events
    WHERE user_id = user_uuid
    GROUP BY event_type
    ORDER BY cnt DESC
    LIMIT 15
  )
  SELECT json_build_object(
    'user_id', user_uuid,
    'user_id_short', left(user_uuid::text, 8),
    'first_seen', (SELECT first_seen FROM basics),
    'last_seen', (SELECT last_seen FROM basics),
    'total_events', (SELECT total_events FROM basics),
    'total_sessions', (SELECT total_sessions FROM basics),
    'total_dreams', (SELECT total_dreams FROM dream_stats),
    'voice_dreams', (SELECT voice_dreams FROM dream_stats),
    'text_dreams', (SELECT text_dreams FROM dream_stats),
    'top_emotions', COALESCE(
      (SELECT json_agg(json_build_object('emotion', e.emotion, 'count', e.cnt)) FROM emotions e),
      '[]'::json
    ),
    'ai_usage', (SELECT json_build_object('titles', titles, 'images', images, 'interpretations', interpretations) FROM ai_usage),
    'active_hour', (SELECT hour FROM active_hour),
    'devices', COALESCE(
      (SELECT json_agg(json_build_object('device', d.device, 'count', d.cnt)) FROM devices d),
      '[]'::json
    ),
    'events_by_day', COALESCE(
      (SELECT json_agg(json_build_object('day', ebd.day, 'count', ebd.cnt) ORDER BY ebd.day) FROM events_by_day ebd),
      '[]'::json
    ),
    'event_type_breakdown', COALESCE(
      (SELECT json_agg(json_build_object('event_type', eb.event_type, 'count', eb.cnt) ORDER BY eb.cnt DESC) FROM event_breakdown eb),
      '[]'::json
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- 3. User Events (paginated event log for one user)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_user_events(
  p_user_id text,
  p_hours int DEFAULT 168,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  user_uuid uuid;
  cutoff timestamptz := now() - (p_hours || ' hours')::interval;
BEGIN
  -- Safe UUID cast
  BEGIN
    user_uuid := p_user_id::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN json_build_object('error', 'Invalid user_id format');
  END;

  WITH events AS (
    SELECT
      id,
      event_type,
      session_id,
      left(session_id::text, 8) AS session_id_short,
      metadata,
      device,
      created_at,
      count(*) OVER()::int AS total_count
    FROM app_events
    WHERE user_id = user_uuid
      AND created_at >= cutoff
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  )
  SELECT json_build_object(
    'events', COALESCE(
      (SELECT json_agg(json_build_object(
        'id', e.id,
        'event_type', e.event_type,
        'session_id', e.session_id,
        'session_id_short', e.session_id_short,
        'metadata', e.metadata,
        'device', e.device,
        'created_at', e.created_at
      ) ORDER BY e.created_at DESC) FROM events e),
      '[]'::json
    ),
    'total', COALESCE((SELECT total_count FROM events LIMIT 1), 0)
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION analytics_user_list(int, int, int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_user_profile(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_user_events(text, int, int, int) TO anon, authenticated, service_role;
