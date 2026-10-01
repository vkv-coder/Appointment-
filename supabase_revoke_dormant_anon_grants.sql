-- ============================================================================
-- Appointment- — document removal of dormant anon grants
-- ============================================================================
-- Already applied directly against the live database. Committed here purely
-- as a record of what changed — safe to re-run, no-op if already revoked.
--
-- CONTEXT
--   A monthly Supabase RLS/RPC audit (2026-10) swept both Supabase projects
--   for tables where the `anon` role held a raw table GRANT (SELECT/INSERT/
--   UPDATE/DELETE) with no RLS policy actually covering that privilege for
--   anon. In Postgres, that combination is inert the moment it happens —
--   with RLS enabled and no matching policy, the role sees/affects zero
--   rows regardless of the grant. But it's a landmine: if a permissive
--   policy for anon/public is ever added later without someone checking
--   existing grants, the table becomes fully exposed with no further step
--   needed. Every instance below was confirmed dormant (live curl tests
--   with the anon key, before and after) before revoking. da_admin_secret
--   and da_owner_sessions are the highest-stakes of this batch -- the
--   latter holds real live session tokens.
-- ============================================================================

REVOKE DELETE, INSERT, SELECT, UPDATE ON public.da_admin_secret FROM anon;
REVOKE DELETE, UPDATE ON public.da_appointments FROM anon;
REVOKE DELETE, INSERT, UPDATE ON public.da_clinics FROM anon;
REVOKE DELETE, INSERT, UPDATE ON public.da_doctors FROM anon;
REVOKE DELETE, INSERT, SELECT, UPDATE ON public.da_owner_sessions FROM anon;
REVOKE DELETE ON public.da_owners FROM anon;
REVOKE DELETE ON public.da_patients FROM anon;
REVOKE DELETE, INSERT, UPDATE ON public.da_schedule FROM anon;
