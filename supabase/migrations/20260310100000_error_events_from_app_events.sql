-- Rewrite error dashboard functions to read from app_events instead of error_events.
-- Maps event_type ending in '_failed' to dashboard categories.

-- Create a view that transforms app_events failures into error_events format
CREATE OR REPLACE VIEW error_events_v AS
SELECT
  id,
  user_id,
  CASE
    WHEN event_type LIKE 'ai_%' THEN 'aiService'
    WHEN event_type LIKE 'audio_%' THEN 'audio'
    WHEN event_type LIKE 'record_%' THEN 'audio'
    WHEN event_type LIKE 'speech_%' THEN 'speech'
    WHEN event_type LIKE 'network_%' THEN 'network'
    WHEN event_type LIKE 'live_%' OR event_type LIKE 'reminder_%' THEN 'liveActivity'
    WHEN event_type LIKE 'data_%' OR event_type LIKE 'dream_%' THEN 'data'
    ELSE 'aiService'
  END AS category,
  event_type AS error_code,
  COALESCE(metadata->>'error', event_type) AS message,
  metadata AS context,
  app_version,
  os_version,
  device,
  locale,
  created_at
FROM app_events
WHERE event_type LIKE '%_failed';

-- Rewrite error_health_summary to use the view
CREATE OR REPLACE FUNCTION public.error_health_summary()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'windows', json_build_object(
      '1h', (
        SELECT json_build_object(
          'total', COUNT(*),
          'affected_users', COUNT(DISTINCT user_id),
          'by_category', (
            SELECT COALESCE(json_object_agg(category, cnt), '{}')
            FROM (SELECT category, COUNT(*) cnt FROM error_events_v WHERE created_at > now() - interval '1 hour' GROUP BY category) s
          )
        )
        FROM error_events_v WHERE created_at > now() - interval '1 hour'
      ),
      '24h', (
        SELECT json_build_object(
          'total', COUNT(*),
          'affected_users', COUNT(DISTINCT user_id),
          'by_category', (
            SELECT COALESCE(json_object_agg(category, cnt), '{}')
            FROM (SELECT category, COUNT(*) cnt FROM error_events_v WHERE created_at > now() - interval '24 hours' GROUP BY category) s
          )
        )
        FROM error_events_v WHERE created_at > now() - interval '24 hours'
      ),
      '7d', (
        SELECT json_build_object(
          'total', COUNT(*),
          'affected_users', COUNT(DISTINCT user_id),
          'by_category', (
            SELECT COALESCE(json_object_agg(category, cnt), '{}')
            FROM (SELECT category, COUNT(*) cnt FROM error_events_v WHERE created_at > now() - interval '7 days' GROUP BY category) s
          )
        )
        FROM error_events_v WHERE created_at > now() - interval '7 days'
      )
    ),
    'top_errors_24h', (
      SELECT COALESCE(json_agg(row_to_json(s)), '[]')
      FROM (
        SELECT error_code, category, COUNT(*) as count, COUNT(DISTINCT user_id) as users
        FROM error_events_v
        WHERE created_at > now() - interval '24 hours'
        GROUP BY error_code, category
        ORDER BY count DESC
        LIMIT 10
      ) s
    )
  ) INTO result;
  RETURN result;
END;
$function$;

-- Rewrite error_timeline
CREATE OR REPLACE FUNCTION public.error_timeline(p_hours integer DEFAULT 24, p_category text DEFAULT NULL, p_error_code text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT COALESCE(json_agg(row_to_json(b)), '[]')
    FROM (
      SELECT
        date_trunc('hour', created_at) AS bucket,
        COUNT(*) AS count,
        COUNT(DISTINCT user_id) AS users
      FROM error_events_v
      WHERE created_at > now() - make_interval(hours => p_hours)
        AND (p_category IS NULL OR category = p_category)
        AND (p_error_code IS NULL OR error_code = p_error_code)
      GROUP BY bucket
      ORDER BY bucket
    ) b
  );
END;
$function$;

-- Rewrite error_details
CREATE OR REPLACE FUNCTION public.error_details(p_hours integer DEFAULT 24, p_category text DEFAULT NULL, p_error_code text DEFAULT NULL, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT json_build_object(
      'total', (
        SELECT COUNT(*) FROM error_events_v
        WHERE created_at > now() - make_interval(hours => p_hours)
          AND (p_category IS NULL OR category = p_category)
          AND (p_error_code IS NULL OR error_code = p_error_code)
      ),
      'events', COALESCE((
        SELECT json_agg(row_to_json(e))
        FROM (
          SELECT id, category, error_code, message, context,
                 app_version, os_version, device, locale, created_at
          FROM error_events_v
          WHERE created_at > now() - make_interval(hours => p_hours)
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code)
          ORDER BY created_at DESC
          LIMIT LEAST(p_limit, 100) OFFSET p_offset
        ) e
      ), '[]')
    )
  );
END;
$function$;

-- Rewrite error_device_breakdown
CREATE OR REPLACE FUNCTION public.error_device_breakdown(p_hours integer DEFAULT 168, p_category text DEFAULT NULL, p_error_code text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN json_build_object(
    'by_device', (
      SELECT COALESCE(json_agg(row_to_json(d)), '[]')
      FROM (
        SELECT device, COUNT(*) AS count, COUNT(DISTINCT user_id) AS users
        FROM error_events_v
        WHERE created_at > now() - make_interval(hours => p_hours)
          AND (p_category IS NULL OR category = p_category)
          AND (p_error_code IS NULL OR error_code = p_error_code)
        GROUP BY device ORDER BY count DESC LIMIT 20
      ) d
    ),
    'by_os_version', (
      SELECT COALESCE(json_agg(row_to_json(o)), '[]')
      FROM (
        SELECT os_version, COUNT(*) AS count, COUNT(DISTINCT user_id) AS users
        FROM error_events_v
        WHERE created_at > now() - make_interval(hours => p_hours)
          AND (p_category IS NULL OR category = p_category)
          AND (p_error_code IS NULL OR error_code = p_error_code)
        GROUP BY os_version ORDER BY count DESC LIMIT 20
      ) o
    ),
    'by_app_version', (
      SELECT COALESCE(json_agg(row_to_json(a)), '[]')
      FROM (
        SELECT app_version, COUNT(*) AS count, COUNT(DISTINCT user_id) AS users
        FROM error_events_v
        WHERE created_at > now() - make_interval(hours => p_hours)
          AND (p_category IS NULL OR category = p_category)
          AND (p_error_code IS NULL OR error_code = p_error_code)
        GROUP BY app_version ORDER BY count DESC LIMIT 20
      ) a
    ),
    'by_locale', (
      SELECT COALESCE(json_agg(row_to_json(l)), '[]')
      FROM (
        SELECT COALESCE(locale, 'unknown') AS locale, COUNT(*) AS count
        FROM error_events_v
        WHERE created_at > now() - make_interval(hours => p_hours)
          AND (p_category IS NULL OR category = p_category)
          AND (p_error_code IS NULL OR error_code = p_error_code)
        GROUP BY locale ORDER BY count DESC LIMIT 20
      ) l
    )
  );
END;
$function$;

-- Rewrite error_trends
CREATE OR REPLACE FUNCTION public.error_trends(p_category text DEFAULT NULL, p_error_code text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN json_build_object(
    'periods', json_build_object(
      '1h', json_build_object(
        'current', (SELECT COUNT(*) FROM error_events_v
          WHERE created_at > now() - interval '1 hour'
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code)),
        'previous', (SELECT COUNT(*) FROM error_events_v
          WHERE created_at BETWEEN now() - interval '2 hours' AND now() - interval '1 hour'
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code))
      ),
      '24h', json_build_object(
        'current', (SELECT COUNT(*) FROM error_events_v
          WHERE created_at > now() - interval '24 hours'
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code)),
        'previous', (SELECT COUNT(*) FROM error_events_v
          WHERE created_at BETWEEN now() - interval '48 hours' AND now() - interval '24 hours'
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code))
      ),
      '7d', json_build_object(
        'current', (SELECT COUNT(*) FROM error_events_v
          WHERE created_at > now() - interval '7 days'
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code)),
        'previous', (SELECT COUNT(*) FROM error_events_v
          WHERE created_at BETWEEN now() - interval '14 days' AND now() - interval '7 days'
            AND (p_category IS NULL OR category = p_category)
            AND (p_error_code IS NULL OR error_code = p_error_code))
      )
    )
  );
END;
$function$;

-- Security: revoke direct access, grant only to service_role
REVOKE ALL ON error_events_v FROM anon, authenticated;
GRANT SELECT ON error_events_v TO service_role;
