-- Fix analytics: schema documentation + 2 SQL function bugs
--
-- 1. CREATE TABLE IF NOT EXISTS app_events — captures the schema that was
--    created manually (outside migrations). Safe: IF NOT EXISTS = no-op on
--    existing databases, but ensures reproducibility on fresh installs.
--
-- 2. analytics_ai_performance() — iOS sends ai_*_started, not ai_*_requested.
--    All _requested references replaced with _started.
--
-- 3. analytics_reminder_stats() — AND binds tighter than OR, so
--    `event_type = 'deep_link_record' OR event_type = 'deep_link_write' AND created_at >= cutoff`
--    was only applying the date filter to deep_link_write. Fixed with parentheses.

-- ============================================================
-- 1. Document app_events table schema
-- ============================================================
CREATE TABLE IF NOT EXISTS app_events (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     UUID NOT NULL,
  event_type  TEXT NOT NULL,
  session_id  UUID NOT NULL,
  metadata    JSONB,
  device      TEXT,
  app_version TEXT NOT NULL DEFAULT '1.0',
  os_version  TEXT NOT NULL DEFAULT 'unknown',
  locale      TEXT NOT NULL DEFAULT 'unknown',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes (IF NOT EXISTS — safe for existing databases)
CREATE INDEX IF NOT EXISTS idx_app_events_user_id ON app_events (user_id);
CREATE INDEX IF NOT EXISTS idx_app_events_event_type ON app_events (event_type);
CREATE INDEX IF NOT EXISTS idx_app_events_created_at ON app_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_events_session_id ON app_events (session_id);

-- RLS (idempotent — already enabled in migration 20260302500000)
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. Fix analytics_ai_performance(): _requested → _started
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
      replace(replace(replace(event_type, '_started', ''), '_completed', ''), '_failed', '') AS service,
      count(*) FILTER (WHERE event_type LIKE '%_started') AS requests,
      count(*) FILTER (WHERE event_type LIKE '%_completed') AS successes,
      count(*) FILTER (WHERE event_type LIKE '%_failed') AS failures
    FROM ai_events
    GROUP BY 1
  ),
  response_times AS (
    SELECT
      replace(req.event_type, '_started', '') AS service,
      avg(EXTRACT(EPOCH FROM (comp.created_at - req.created_at)))::numeric AS avg_response_sec
    FROM ai_events req
    JOIN ai_events comp ON req.session_id = comp.session_id
      AND replace(req.event_type, '_started', '_completed') = comp.event_type
      AND comp.created_at > req.created_at
      AND comp.created_at < req.created_at + interval '2 minutes'
    WHERE req.event_type LIKE '%_started'
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
-- 3. Fix analytics_reminder_stats(): OR/AND precedence
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
    WHERE (event_type = 'deep_link_record' OR event_type = 'deep_link_write')
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
-- Re-apply security: revoke from public, grant to service_role
-- ============================================================
REVOKE ALL ON FUNCTION analytics_ai_performance(int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics_ai_performance(int) TO service_role;
REVOKE ALL ON FUNCTION analytics_reminder_stats(int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics_reminder_stats(int) TO service_role;
