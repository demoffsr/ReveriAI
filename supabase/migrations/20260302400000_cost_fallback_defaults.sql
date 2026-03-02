-- Add default cost fallbacks for events without cost_usd in metadata
-- Uses estimated prices when metadata->>'cost_usd' is NULL (pre-tracking events)

CREATE OR REPLACE FUNCTION analytics_user_costs(
  p_user_id text DEFAULT NULL,
  p_days int DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  v_user_id uuid;
BEGIN
  IF p_user_id IS NOT NULL AND p_user_id != '' THEN
    v_user_id := p_user_id::uuid;
  END IF;

  WITH cost_events AS (
    SELECT
      user_id,
      event_type,
      COALESCE(
        (metadata->>'cost_usd')::numeric,
        CASE event_type
          WHEN 'ai_title_completed' THEN 0.0003
          WHEN 'ai_image_completed' THEN 0.168
          WHEN 'ai_interpretation_completed' THEN 0.003
          WHEN 'ai_transcription_completed' THEN 0.006
          ELSE 0
        END
      ) AS cost_usd,
      created_at
    FROM app_events
    WHERE event_type IN (
      'ai_title_completed', 'ai_image_completed',
      'ai_interpretation_completed', 'ai_transcription_completed'
    )
    AND created_at >= NOW() - (p_days || ' days')::interval
    AND (v_user_id IS NULL OR user_id = v_user_id)
  ),
  per_user AS (
    SELECT
      user_id,
      COUNT(*) AS total_ops,
      SUM(cost_usd) AS total_cost,
      SUM(CASE WHEN event_type = 'ai_title_completed' THEN cost_usd ELSE 0 END) AS title_cost,
      SUM(CASE WHEN event_type = 'ai_image_completed' THEN cost_usd ELSE 0 END) AS image_cost,
      SUM(CASE WHEN event_type = 'ai_interpretation_completed' THEN cost_usd ELSE 0 END) AS interpretation_cost,
      SUM(CASE WHEN event_type = 'ai_transcription_completed' THEN cost_usd ELSE 0 END) AS transcription_cost,
      COUNT(*) FILTER (WHERE event_type = 'ai_title_completed') AS title_count,
      COUNT(*) FILTER (WHERE event_type = 'ai_image_completed') AS image_count,
      COUNT(*) FILTER (WHERE event_type = 'ai_interpretation_completed') AS interpretation_count,
      COUNT(*) FILTER (WHERE event_type = 'ai_transcription_completed') AS transcription_count
    FROM cost_events
    GROUP BY user_id
  ),
  daily_costs AS (
    SELECT
      DATE(created_at) AS day,
      SUM(cost_usd) AS daily_total
    FROM cost_events
    GROUP BY DATE(created_at)
    ORDER BY day
  ),
  totals AS (
    SELECT
      COUNT(DISTINCT user_id) AS unique_users,
      SUM(total_cost) AS grand_total,
      AVG(total_cost) AS avg_per_user,
      MAX(total_cost) AS max_per_user,
      SUM(total_ops) AS total_operations,
      SUM(title_cost) AS total_title_cost,
      SUM(image_cost) AS total_image_cost,
      SUM(interpretation_cost) AS total_interpretation_cost,
      SUM(transcription_cost) AS total_transcription_cost,
      SUM(title_count) AS total_titles,
      SUM(image_count) AS total_images,
      SUM(interpretation_count) AS total_interpretations,
      SUM(transcription_count) AS total_transcriptions
    FROM per_user
  )
  SELECT jsonb_build_object(
    'summary', (SELECT row_to_json(t)::jsonb FROM totals t),
    'by_user', COALESCE(
      (SELECT jsonb_agg(row_to_json(pu)::jsonb ORDER BY pu.total_cost DESC)
       FROM per_user pu),
      '[]'::jsonb
    ),
    'daily', COALESCE(
      (SELECT jsonb_agg(jsonb_build_object('day', day, 'cost', daily_total) ORDER BY day)
       FROM daily_costs),
      '[]'::jsonb
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- Update analytics_user_list cost CTE
CREATE OR REPLACE FUNCTION analytics_user_list(
  p_days int DEFAULT 30,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  WITH user_stats AS (
    SELECT
      user_id,
      COUNT(*) AS event_count,
      COUNT(DISTINCT session_id) AS session_count,
      MIN(created_at) AS first_seen,
      MAX(created_at) AS last_event
    FROM app_events
    WHERE created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY user_id
  ),
  dream_counts AS (
    SELECT
      user_id,
      COUNT(*) AS dream_count
    FROM app_events
    WHERE event_type IN ('dream_recorded', 'review_saved_audio')
      AND created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY user_id
  ),
  cost_stats AS (
    SELECT
      user_id,
      SUM(COALESCE(
        (metadata->>'cost_usd')::numeric,
        CASE event_type
          WHEN 'ai_title_completed' THEN 0.0003
          WHEN 'ai_image_completed' THEN 0.168
          WHEN 'ai_interpretation_completed' THEN 0.003
          WHEN 'ai_transcription_completed' THEN 0.006
          ELSE 0
        END
      )) AS total_cost
    FROM app_events
    WHERE event_type IN (
      'ai_title_completed', 'ai_image_completed',
      'ai_interpretation_completed', 'ai_transcription_completed'
    )
    AND created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY user_id
  ),
  last_events AS (
    SELECT DISTINCT ON (user_id)
      user_id, event_type AS last_event_type
    FROM app_events
    WHERE created_at >= NOW() - (p_days || ' days')::interval
    ORDER BY user_id, created_at DESC
  ),
  device_mode AS (
    SELECT DISTINCT ON (user_id)
      user_id, device
    FROM app_events
    WHERE device IS NOT NULL
      AND created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY user_id, device
    ORDER BY user_id, COUNT(*) DESC
  )
  SELECT jsonb_build_object(
    'users', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', u.user_id,
        'events', u.event_count,
        'sessions', u.session_count,
        'dreams', COALESCE(d.dream_count, 0),
        'total_cost_usd', COALESCE(c.total_cost, 0),
        'last_event', u.last_event,
        'first_seen', u.first_seen,
        'last_event_type', le.last_event_type,
        'device', dm.device
      ) ORDER BY u.last_event DESC)
      FROM (
        SELECT * FROM user_stats
        ORDER BY last_event DESC
        LIMIT p_limit OFFSET p_offset
      ) u
      LEFT JOIN dream_counts d ON d.user_id = u.user_id
      LEFT JOIN cost_stats c ON c.user_id = u.user_id
      LEFT JOIN last_events le ON le.user_id = u.user_id
      LEFT JOIN device_mode dm ON dm.user_id = u.user_id
    ), '[]'::jsonb),
    'total', (SELECT COUNT(DISTINCT user_id) FROM user_stats)
  ) INTO result;

  RETURN result;
END;
$$;

-- Update analytics_user_profile cost breakdown
CREATE OR REPLACE FUNCTION analytics_user_profile(p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
  v_user_id uuid;
BEGIN
  v_user_id := p_user_id::uuid;

  WITH basics AS (
    SELECT
      COUNT(*) AS total_events,
      COUNT(DISTINCT session_id) AS total_sessions,
      MIN(created_at) AS first_seen,
      MAX(created_at) AS last_seen,
      MAX(device) AS device,
      MAX(app_version) AS app_version,
      MAX(os_version) AS os_version,
      MAX(locale) AS locale
    FROM app_events WHERE user_id = v_user_id
  ),
  dream_stats AS (
    SELECT
      COUNT(*) FILTER (WHERE event_type = 'dream_recorded') AS text_dreams,
      COUNT(*) FILTER (WHERE event_type = 'review_saved_audio') AS audio_dreams,
      COUNT(*) FILTER (WHERE event_type IN ('dream_recorded','review_saved_audio')) AS total_dreams
    FROM app_events WHERE user_id = v_user_id
  ),
  emotions AS (
    SELECT metadata->>'emotions' AS emotion, COUNT(*) AS cnt
    FROM app_events
    WHERE user_id = v_user_id AND event_type = 'emotions_selected'
      AND metadata->>'emotions' IS NOT NULL
    GROUP BY metadata->>'emotions'
    ORDER BY cnt DESC LIMIT 5
  ),
  ai_usage AS (
    SELECT
      COUNT(*) FILTER (WHERE event_type = 'ai_title_completed') AS titles,
      COUNT(*) FILTER (WHERE event_type = 'ai_image_completed') AS images,
      COUNT(*) FILTER (WHERE event_type = 'ai_interpretation_completed') AS interpretations,
      COUNT(*) FILTER (WHERE event_type = 'ai_transcription_completed') AS transcriptions,
      COUNT(*) FILTER (WHERE event_type LIKE 'ai_%_failed') AS failures
    FROM app_events WHERE user_id = v_user_id
  ),
  cost_breakdown AS (
    SELECT
      SUM(COALESCE(
        (metadata->>'cost_usd')::numeric,
        CASE event_type
          WHEN 'ai_title_completed' THEN 0.0003
          WHEN 'ai_image_completed' THEN 0.168
          WHEN 'ai_interpretation_completed' THEN 0.003
          WHEN 'ai_transcription_completed' THEN 0.006
          ELSE 0
        END
      )) AS total_cost,
      SUM(CASE WHEN event_type = 'ai_title_completed'
          THEN COALESCE((metadata->>'cost_usd')::numeric, 0.0003) ELSE 0 END) AS title_cost,
      SUM(CASE WHEN event_type = 'ai_image_completed'
          THEN COALESCE((metadata->>'cost_usd')::numeric, 0.168) ELSE 0 END) AS image_cost,
      SUM(CASE WHEN event_type = 'ai_interpretation_completed'
          THEN COALESCE((metadata->>'cost_usd')::numeric, 0.003) ELSE 0 END) AS interpretation_cost,
      SUM(CASE WHEN event_type = 'ai_transcription_completed'
          THEN COALESCE((metadata->>'cost_usd')::numeric, 0.006) ELSE 0 END) AS transcription_cost
    FROM app_events
    WHERE user_id = v_user_id
      AND event_type IN (
        'ai_title_completed', 'ai_image_completed',
        'ai_interpretation_completed', 'ai_transcription_completed'
      )
  ),
  active_hour AS (
    SELECT EXTRACT(HOUR FROM created_at)::int AS hour, COUNT(*) AS cnt
    FROM app_events WHERE user_id = v_user_id
    GROUP BY hour ORDER BY cnt DESC LIMIT 1
  ),
  devices AS (
    SELECT device, COUNT(*) AS cnt
    FROM app_events WHERE user_id = v_user_id AND device IS NOT NULL
    GROUP BY device ORDER BY cnt DESC
  ),
  events_by_day AS (
    SELECT DATE(created_at) AS day, COUNT(*) AS cnt
    FROM app_events WHERE user_id = v_user_id
      AND created_at >= NOW() - interval '30 days'
    GROUP BY day ORDER BY day
  ),
  event_type_breakdown AS (
    SELECT event_type, COUNT(*) AS cnt
    FROM app_events WHERE user_id = v_user_id
    GROUP BY event_type ORDER BY cnt DESC
  )
  SELECT jsonb_build_object(
    'basics', (SELECT row_to_json(b)::jsonb FROM basics b),
    'dream_stats', (SELECT row_to_json(d)::jsonb FROM dream_stats d),
    'emotions', COALESCE((SELECT jsonb_agg(row_to_json(e)::jsonb) FROM emotions e), '[]'::jsonb),
    'ai_usage', (SELECT row_to_json(a)::jsonb FROM ai_usage a),
    'costs', (SELECT row_to_json(c)::jsonb FROM cost_breakdown c),
    'active_hour', (SELECT hour FROM active_hour),
    'devices', COALESCE((SELECT jsonb_agg(row_to_json(d)::jsonb) FROM devices d), '[]'::jsonb),
    'events_by_day', COALESCE((SELECT jsonb_agg(jsonb_build_object('day', day, 'count', cnt)) FROM events_by_day), '[]'::jsonb),
    'event_types', COALESCE((SELECT jsonb_agg(jsonb_build_object('type', event_type, 'count', cnt)) FROM event_type_breakdown), '[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;
