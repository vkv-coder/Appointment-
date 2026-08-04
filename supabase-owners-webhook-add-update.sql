-- The Supabase "Database Webhook" watching da_owners was created via the
-- dashboard UI as AFTER INSERT only, so approving/rejecting a provider
-- (an UPDATE to da_owners.status) never reached google-apps-script.gs at
-- all - not a code bug, the webhook simply wasn't listening for that event.
-- Recreating it with the same target/settings, adding UPDATE.

drop trigger if exists new_owner_signup on public.da_owners;
create trigger new_owner_signup
after insert or update on public.da_owners
for each row execute function supabase_functions.http_request(
  'https://script.google.com/macros/s/AKfycbwFRCZIqTT7HKeAdhROmy3iU4ib9IMIPe6IL4rmkQAR5GKPJNxi5LY6C_PGoaaumw/exec',
  'POST',
  '{"Content-Type":"application/json"}',
  '{}',
  '5000'
);
