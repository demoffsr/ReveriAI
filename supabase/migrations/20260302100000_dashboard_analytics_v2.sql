-- Dashboard Analytics V2: 6 new functions for extended analytics
-- Heatmap, AI Performance, Reminder Stats, Dream Stats, Retention by Action, Live Events

-- ============================================================
-- 1. Activity Heatmap (GitHub-style hour×day grid)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_activity_heatmap(p_days int DEFAULT 30)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  SELECT COALESCE(
    json_agg(row_to_json(t) ORDER BY t.day_of_week, t.hour),
    '[]'::json
  ) INTO result
  FROM (
    SELECT
      EXTRACT(DOW FROM created_at)::int AS day_of_week,
      EXTRACT(HOUR FROM created_at)::int AS hour,
      count(*)::int AS event_count,
      count(DISTINCT user_id)::int AS unique_users
    FROM app_events
    WHERE created_at >= now() - (p_days || ' days')::interval
    GROUP BY 1, 2
  ) t;

  RETURN result;
END;
$$;

-- ============================================================
-- 2. Retention by Action (compare cohorts)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_retention_by_action(
  p_action text DEFAULT 'dream_recorded',
  p_threshold int DEFAULT 3,
  p_days int DEFAULT 30
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  WITH user_first_seen AS (
    SELECT user_id, min(created_at) AS first_seen
    FROM app_events
    WHERE created_at >= now() - (p_days || ' days')::interval
    GROUP BY user_id
  ),
  action_counts AS (
    SELECT ae.user_id, count(*) AS action_count
    FROM app_events ae
    JOIN user_first_seen ufs ON ae.user_id = ufs.user_id
    WHERE ae.event_type = p_action
      AND ae.created_at >= ufs.first_seen
      AND ae.created_at < ufs.first_seen + interval '7 days'
    GROUP BY ae.user_id
  ),
  cohorts AS (
    SELECT
      ufs.user_id,
      ufs.first_seen,
      CASE WHEN COALESCE(ac.action_count, 0) >= p_threshold
           THEN 'active' ELSE 'control' END AS cohort
    FROM user_first_seen ufs
    LEFT JOIN action_counts ac ON ufs.user_id = ac.user_id
  ),
  retention AS (
    SELECT
      c.cohort,
      count(DISTINCT c.user_id)::int AS total_users,
      count(DISTINCT CASE
        WHEN EXISTS (
          SELECT 1 FROM app_events ae
          WHERE ae.user_id = c.user_id
            AND ae.created_at >= c.first_seen + interval '6 days'
            AND ae.created_at < c.first_seen + interval '8 days'
        ) THEN c.user_id END
      )::int AS d7_retained,
      count(DISTINCT CASE
        WHEN EXISTS (
          SELECT 1 FROM app_events ae
          WHERE ae.user_id = c.user_id
            AND ae.created_at >= c.first_seen + interval '27 days'
            AND ae.created_at < c.first_seen + interval '33 days'
        ) THEN c.user_id END
      )::int AS d30_retained
    FROM cohorts c
    WHERE c.first_seen <= now() - interval '7 days'
    GROUP BY c.cohort
  )
  SELECT json_build_object(
    'action', p_action,
    'threshold', p_threshold,
    'cohorts', COALESCE(
      (SELECT json_agg(json_build_object(
        'cohort', r.cohort,
        'total_users', r.total_users,
        'd7_retained', r.d7_retained,
        'd7_pct', CASE WHEN r.total_users > 0
          THEN round(r.d7_retained::numeric / r.total_users * 100, 1) ELSE 0 END,
        'd30_retained', r.d30_retained,
        'd30_pct', CASE WHEN r.total_users > 0
          THEN round(r.d30_retained::numeric / r.total_users * 100, 1) ELSE 0 END
      )) FROM retention r),
      '[]'::json
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- 3. AI Performance (success rates + response times)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_ai_performance(p_hours int DEFAULT 24)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  cutoff timestamptz := now() - (p_hours || ' hours')::interval;
BEGIN
  WITH ai_events AS (
    SELECT event_type, created_at, session_id, metadata
    FROM app_events
    WHERE created_at >= cutoff
      AND event_type LIKE 'ai_%'
  ),
  service_stats AS (
    SELECT
      replace(replace(replace(event_type, '_requested', ''), '_completed', ''), '_failed', '') AS service,
      count(*) FILTER (WHERE event_type LIKE '%_requested') AS requests,
      count(*) FILTER (WHERE event_type LIKE '%_completed') AS successes,
      count(*) FILTER (WHERE event_type LIKE '%_failed') AS failures
    FROM ai_events
    GROUP BY 1
  ),
  response_times AS (
    SELECT
      replace(req.event_type, '_requested', '') AS service,
      avg(EXTRACT(EPOCH FROM (comp.created_at - req.created_at)))::numeric AS avg_response_sec
    FROM ai_events req
    JOIN ai_events comp ON req.session_id = comp.session_id
      AND replace(req.event_type, '_requested', '_completed') = comp.event_type
      AND comp.created_at > req.created_at
      AND comp.created_at < req.created_at + interval '2 minutes'
    WHERE req.event_type LIKE '%_requested'
    GROUP BY 1
  ),
  timeline AS (
    SELECT
      date_trunc('hour', created_at) AS hour,
      count(*) FILTER (WHERE event_type LIKE 'ai_title%')::int AS titles,
      count(*) FILTER (WHERE event_type LIKE 'ai_image%')::int AS images,
      count(*) FILTER (WHERE event_type LIKE 'ai_interpretation%')::int AS interps
    FROM ai_events
    GROUP BY 1
    ORDER BY 1
  )
  SELECT json_build_object(
    'services', COALESCE(
      (SELECT json_agg(json_build_object(
        'service', ss.service,
        'requests', ss.requests,
        'successes', ss.successes,
        'failures', ss.failures,
        'success_rate', CASE WHEN ss.requests > 0
          THEN round(ss.successes::numeric / ss.requests * 100, 1) ELSE 0 END,
        'avg_response_sec', COALESCE(round(rt.avg_response_sec, 2), 0)
      )) FROM service_stats ss
      LEFT JOIN response_times rt ON ss.service = rt.service),
      '[]'::json
    ),
    'timeline', COALESCE(
      (SELECT json_agg(json_build_object(
        'hour', tl.hour,
        'titles', tl.titles,
        'images', tl.images,
        'interps', tl.interps
      ) ORDER BY tl.hour) FROM timeline tl),
      '[]'::json
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- 4. Reminder Stats (effectiveness tracking)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_reminder_stats(p_days int DEFAULT 30)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  cutoff timestamptz := now() - (p_days || ' days')::interval;
BEGIN
  WITH reminders AS (
    SELECT id, user_id, created_at, session_id
    FROM app_events
    WHERE event_type = 'deep_link_record' OR event_type = 'deep_link_write'
      AND created_at >= cutoff
  ),
  followups AS (
    SELECT
      r.id AS reminder_id,
      r.user_id,
      r.created_at AS reminder_at,
      EXTRACT(DOW FROM r.created_at)::int AS dow,
      EXTRACT(HOUR FROM r.created_at)::int AS hour,
      EXISTS (
        SELECT 1 FROM app_events ae
        WHERE ae.user_id = r.user_id
          AND ae.event_type = 'record_started'
          AND ae.created_at > r.created_at
          AND ae.created_at < r.created_at + interval '60 minutes'
      ) AS led_to_record,
      EXISTS (
        SELECT 1 FROM app_events ae
        WHERE ae.user_id = r.user_id
          AND ae.event_type = 'dream_recorded'
          AND ae.created_at > r.created_at
          AND ae.created_at < r.created_at + interval '120 minutes'
      ) AS led_to_dream
    FROM reminders r
  )
  SELECT json_build_object(
    'total_reminders', (SELECT count(*) FROM followups),
    'led_to_record', (SELECT count(*) FILTER (WHERE led_to_record) FROM followups),
    'led_to_dream', (SELECT count(*) FILTER (WHERE led_to_dream) FROM followups),
    'record_rate_pct', CASE WHEN (SELECT count(*) FROM followups) > 0
      THEN round((SELECT count(*) FILTER (WHERE led_to_record) FROM followups)::numeric /
           (SELECT count(*) FROM followups) * 100, 1) ELSE 0 END,
    'dream_rate_pct', CASE WHEN (SELECT count(*) FROM followups) > 0
      THEN round((SELECT count(*) FILTER (WHERE led_to_dream) FROM followups)::numeric /
           (SELECT count(*) FROM followups) * 100, 1) ELSE 0 END,
    'by_day_of_week', COALESCE(
      (SELECT json_agg(json_build_object(
        'dow', f.dow,
        'total', count(*),
        'recorded', count(*) FILTER (WHERE f.led_to_record),
        'dreamed', count(*) FILTER (WHERE f.led_to_dream)
      ) ORDER BY f.dow)
      FROM followups f GROUP BY f.dow),
      '[]'::json
    ),
    'by_hour', COALESCE(
      (SELECT json_agg(json_build_object(
        'hour', f.hour,
        'total', count(*),
        'recorded', count(*) FILTER (WHERE f.led_to_record),
        'dreamed', count(*) FILTER (WHERE f.led_to_dream)
      ) ORDER BY f.hour)
      FROM followups f GROUP BY f.hour),
      '[]'::json
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- 5. Dream Stats (emotions, length, trends)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_dream_stats(p_hours int DEFAULT 168)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
  cutoff timestamptz := now() - (p_hours || ' hours')::interval;
BEGIN
  WITH dream_events AS (
    SELECT event_type, metadata, created_at
    FROM app_events
    WHERE created_at >= cutoff
      AND event_type IN ('dream_recorded', 'review_saved_audio')
  ),
  totals AS (
    SELECT
      count(*) AS total,
      count(*) FILTER (WHERE event_type = 'review_saved_audio') AS voice,
      count(*) FILTER (WHERE event_type = 'dream_recorded'
        AND (metadata->>'mode') = 'text') AS text_mode
    FROM dream_events
  ),
  emotions AS (
    SELECT
      emotion,
      count(*)::int AS cnt
    FROM app_events,
      jsonb_array_elements_text(COALESCE(metadata->'emotions', '[]'::jsonb)) AS emotion
    WHERE created_at >= cutoff
      AND event_type IN ('dream_recorded', 'review_saved_audio')
      AND metadata ? 'emotions'
    GROUP BY emotion
    ORDER BY cnt DESC
  ),
  daily AS (
    SELECT
      date_trunc('day', created_at)::date AS day,
      count(*)::int AS cnt
    FROM dream_events
    GROUP BY 1
    ORDER BY 1
  ),
  ai_usage AS (
    SELECT
      count(*) FILTER (WHERE event_type = 'ai_title_completed') AS with_title,
      count(*) FILTER (WHERE event_type = 'ai_image_completed') AS with_image
    FROM app_events
    WHERE created_at >= cutoff
  ),
  text_lengths AS (
    SELECT
      CASE
        WHEN (metadata->>'text_length')::int < 50 THEN 'short'
        WHEN (metadata->>'text_length')::int < 200 THEN 'medium'
        ELSE 'long'
      END AS bucket,
      count(*)::int AS cnt
    FROM app_events
    WHERE created_at >= cutoff
      AND event_type IN ('dream_recorded', 'review_saved_audio')
      AND metadata ? 'text_length'
    GROUP BY 1
  )
  SELECT json_build_object(
    'total_dreams', (SELECT total FROM totals),
    'voice_dreams', (SELECT voice FROM totals),
    'text_dreams', (SELECT text_mode FROM totals),
    'emotions', COALESCE(
      (SELECT json_agg(json_build_object(
        'emotion', e.emotion,
        'count', e.cnt
      )) FROM emotions e),
      '[]'::json
    ),
    'daily', COALESCE(
      (SELECT json_agg(json_build_object(
        'day', d.day,
        'count', d.cnt
      ) ORDER BY d.day) FROM daily d),
      '[]'::json
    ),
    'ai_titles', (SELECT with_title FROM ai_usage),
    'ai_images', (SELECT with_image FROM ai_usage),
    'length_buckets', COALESCE(
      (SELECT json_agg(json_build_object(
        'bucket', tl.bucket,
        'count', tl.cnt
      )) FROM text_lengths tl),
      '[]'::json
    )
  ) INTO result;

  RETURN result;
END;
$$;

-- ============================================================
-- 6. Live Events Feed (latest N events)
-- ============================================================
CREATE OR REPLACE FUNCTION analytics_live_events(p_limit int DEFAULT 50)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  SELECT COALESCE(
    json_agg(json_build_object(
      'id', t.id,
      'event_type', t.event_type,
      'session_id', left(t.session_id::text, 8),
      'user_id', left(t.user_id::text, 8),
      'metadata', t.metadata,
      'device', t.device,
      'created_at', t.created_at
    ) ORDER BY t.created_at DESC),
    '[]'::json
  ) INTO result
  FROM (
    SELECT id, event_type, session_id, user_id, metadata, device, created_at
    FROM app_events
    ORDER BY created_at DESC
    LIMIT p_limit
  ) t;

  RETURN result;
END;
$$;

-- ============================================================
-- Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION analytics_activity_heatmap(int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_retention_by_action(text, int, int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_ai_performance(int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_reminder_stats(int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_dream_stats(int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION analytics_live_events(int) TO anon, authenticated, service_role;
