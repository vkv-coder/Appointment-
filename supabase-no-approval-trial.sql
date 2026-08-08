-- Switch to no-approval-required free trial:
-- - signup.html now inserts status:'approved' directly (see code change)
-- - trial_started_at is set on first REAL data entry (first clinic or first
--   doctor added), not at signup and not at login, matching consultrack's
--   "trial starts on first real use" principle
-- - trial_reminder_sent lets the 3-days-left reminder fire exactly once per
--   trial window (reset if the trial is ever extended, so a re-extended
--   owner gets a fresh reminder later too)

alter table da_owners add column if not exists trial_reminder_sent boolean not null default false;

create or replace function public.da_start_trial_if_needed(p_owner_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_owner da_owners%rowtype;
begin
  select * into v_owner from da_owners where id = p_owner_id;
  if v_owner.id is null then return; end if;
  if v_owner.trial_started_at is not null then return; end if;
  if v_owner.username = 'demo_owner' then return; end if;
  update da_owners set trial_started_at = now() where id = p_owner_id;
end;
$function$;

create or replace function public.da_owner_add_clinic(p_token uuid, p_name text, p_address text, p_off_days int[])
returns da_clinics
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_owner_id uuid; v_row da_clinics%rowtype;
begin
  v_owner_id := da_require_owner_session(p_token);
  perform da_start_trial_if_needed(v_owner_id);
  insert into da_clinics(owner_id,name,address,off_days) values (v_owner_id,p_name,p_address,p_off_days) returning * into v_row;
  return v_row;
end; $function$;

create or replace function public.da_owner_add_doctor(p_token uuid, p_name text, p_telegram_chat_id text, p_email text, p_booking_mode text)
returns da_doctors
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_owner_id uuid; v_row da_doctors%rowtype;
begin
  v_owner_id := da_require_owner_session(p_token);
  perform da_start_trial_if_needed(v_owner_id);
  insert into da_doctors(owner_id,name,telegram_chat_id,email,booking_mode) values (v_owner_id,p_name,p_telegram_chat_id,p_email,p_booking_mode) returning * into v_row;
  return v_row;
end; $function$;

create or replace function public.da_admin_extend_trial(p_owner_id uuid, p_admin_password text, p_days int)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
begin
  if not da_admin_check_password(p_admin_password) then raise exception 'Unauthorized'; end if;
  if p_days is null or p_days < 1 then raise exception 'Invalid number of days'; end if;
  update da_owners set trial_extended_days = trial_extended_days + p_days, trial_reminder_sent = false where id = p_owner_id;
  return true;
end;
$function$;

-- Remove the earlier "start trial on first login" behavior - superseded by
-- da_start_trial_if_needed, which now fires on first real data entry
-- (first clinic/doctor added) instead.
drop function if exists public.da_owner_login(text, text);
create or replace function public.da_owner_login(p_username text, p_password text)
returns table(session_token uuid, id uuid, clinic_group_name text, owner_name text, phone text, email text, username text, status text, broad_category text, category text, telegram_chat_id text, trial_started_at timestamptz, trial_extended_days int, is_blocked boolean)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_owner da_owners%rowtype; v_token uuid;
begin
  select * into v_owner from da_owners o where o.username = p_username and o.password = crypt(p_password, o.password);
  if v_owner.id is null then
    raise exception 'Invalid username or password';
  end if;

  insert into da_owner_sessions (owner_id) values (v_owner.id) returning token into v_token;
  return query select v_token, v_owner.id, v_owner.clinic_group_name, v_owner.owner_name, v_owner.phone, v_owner.email, v_owner.username, v_owner.status, v_owner.broad_category, v_owner.category, v_owner.telegram_chat_id, v_owner.trial_started_at, v_owner.trial_extended_days, v_owner.is_blocked;
end;
$function$;
