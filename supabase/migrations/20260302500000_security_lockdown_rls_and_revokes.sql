-- Security Lockdown: RLS + Revoke Public Access
-- Closes critical vulnerabilities:
--   1. app_events table exposed without RLS (any anon key holder could SELECT * all user data)
--   2. rate_limits table exposed without RLS
--   3. 29 SQL functions accessible to anon/authenticated via PostgREST RPC
--
-- iOS app uses only edge functions via service_role — nothing breaks.

-- ============================================================================
-- 1. REVOKE all analytics/error/rate-limit functions from public access
-- ============================================================================
-- Dynamic loop covers all overloads and unlisted functions (created via SQL Editor).
-- Includes:
--   analytics_* (14 from migrations + 15 unlisted from app-status edge function)
--   error_* (5 unlisted from app-status edge function)
--   check_rate_limits, cleanup_rate_limits

DO $$
DECLARE
  func_record RECORD;
BEGIN
  FOR func_record IN
    SELECT p.oid::regprocedure AS func_signature
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
  END LOOP;
END $$;

-- ============================================================================
-- 2. Enable RLS on tables (zero policies = complete lockdown)
-- ============================================================================
-- service_role bypasses RLS automatically.

ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- KNOWN RISKS:
-- 1. SECURITY DEFINER: все analytics-функции выполняются от владельца (postgres),
--    обходя RLS. Если в будущем добавите GRANT обратно для authenticated —
--    функции дадут доступ ко ВСЕМ данным, не только к данным вызывающего юзера.
--    Решение: при необходимости прямого доступа — переписать на SECURITY INVOKER.
--
-- 2. user_id spoofing: track-event edge function не валидирует auth.
--    Любой может отправить events с чужим user_id. INSERT идёт через
--    service_role → RLS не поможет. Отдельная задача для фикса.
--
-- CONVENTION: При создании новых public-schema функций ВСЕГДА добавлять:
--   REVOKE ALL ON FUNCTION <name>(<args>) FROM PUBLIC;
--   REVOKE ALL ON FUNCTION <name>(<args>) FROM anon, authenticated;
--   GRANT EXECUTE ON FUNCTION <name>(<args>) TO service_role;
--   Прямой клиентский RPC-доступ запрещён by design.
-- ============================================================================
