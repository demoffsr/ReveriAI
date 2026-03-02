-- Table: server-issued anonymous analytics identities
CREATE TABLE IF NOT EXISTS analytics_devices (
  user_id      UUID PRIMARY KEY,
  token_hash   TEXT NOT NULL UNIQUE,      -- SHA-256(raw_token), indexed for lookup
  device       TEXT,
  os_version   TEXT,
  app_version  TEXT,
  ip_hash      TEXT,                      -- HMAC-SHA256(secret, ip), NOT raw SHA-256
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS: zero policies = service_role only
ALTER TABLE analytics_devices ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE analytics_devices FROM anon, authenticated;

-- Index for token lookup (primary validation path)
CREATE UNIQUE INDEX idx_analytics_devices_token_hash ON analytics_devices (token_hash);

-- Index for cleanup job
CREATE INDEX idx_analytics_devices_last_seen ON analytics_devices (last_seen_at);

-- Cleanup function: delete devices inactive > 365 days
CREATE OR REPLACE FUNCTION cleanup_analytics_devices()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM analytics_devices WHERE last_seen_at < now() - interval '365 days';
$$;

REVOKE ALL ON FUNCTION cleanup_analytics_devices() FROM PUBLIC;
REVOKE ALL ON FUNCTION cleanup_analytics_devices() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_analytics_devices() TO service_role;

-- Monitoring view: unverified event ratio for dashboard
CREATE OR REPLACE FUNCTION analytics_auth_health(p_hours INT DEFAULT 24)
RETURNS TABLE(
  total_events BIGINT,
  verified_events BIGINT,
  unverified_events BIGINT,
  unverified_pct NUMERIC,
  registered_devices BIGINT,
  registrations_24h BIGINT
) LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT
    COUNT(*)::BIGINT AS total_events,
    COUNT(*) FILTER (WHERE metadata->>'_unverified' IS NULL)::BIGINT AS verified_events,
    COUNT(*) FILTER (WHERE metadata->>'_unverified' IS NOT NULL)::BIGINT AS unverified_events,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE metadata->>'_unverified' IS NOT NULL) /
      GREATEST(COUNT(*), 1),
      1
    ) AS unverified_pct,
    (SELECT COUNT(*) FROM analytics_devices)::BIGINT AS registered_devices,
    (SELECT COUNT(*) FROM analytics_devices WHERE created_at > now() - interval '24 hours')::BIGINT AS registrations_24h
  FROM app_events
  WHERE created_at > now() - make_interval(hours => p_hours);
$$;

REVOKE ALL ON FUNCTION analytics_auth_health(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION analytics_auth_health(INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics_auth_health(INT) TO service_role;
