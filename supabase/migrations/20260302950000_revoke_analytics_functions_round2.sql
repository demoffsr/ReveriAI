-- Round 2: Re-lock analytics/error functions created after initial lockdown
--
-- Problem: migrations 20260302100000–20260302400000 contain explicit
--   GRANT EXECUTE ... TO anon, authenticated, service_role
-- If they were applied AFTER the lockdown (20260302500000), those GRANTs
-- re-opened access. This migration re-runs the same dynamic loop.
--
-- Safe to re-run: REVOKE on already-revoked = no-op.

DO $$
DECLARE
  func_record RECORD;
  revoked_count INT := 0;
BEGIN
  FOR func_record IN
    SELECT p.oid::regprocedure AS func_signature, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND (
        p.proname LIKE 'analytics_%'
        OR p.proname LIKE 'error_%'
        OR p.proname IN ('check_rate_limits', 'cleanup_rate_limits')
      )
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', func_record.func_signature);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM anon, authenticated', func_record.func_signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', func_record.func_signature);
    revoked_count := revoked_count + 1;
  END LOOP;

  RAISE NOTICE 'Locked down % functions', revoked_count;
END $$;
