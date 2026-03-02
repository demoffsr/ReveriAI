-- Belt-and-suspenders: explicit REVOKE on tables
-- RLS with zero policies already blocks access, but Supabase default-grants
-- ALL ON ALL TABLES to anon/authenticated. Explicit REVOKE protects against
-- accidental permissive policy creation in the future.

REVOKE ALL ON TABLE app_events FROM anon, authenticated;
REVOKE ALL ON TABLE rate_limits FROM anon, authenticated;
