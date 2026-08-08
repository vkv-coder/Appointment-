-- Trial/subscription tracking for da_owners, matching the pattern already
-- proven in consultrack (professionals.trial_started_at / trial_extended_days
-- / is_blocked, TRIAL_DAYS=30, checkTrialAndEnter() client-side gate).
--
-- Trial starts on first LOGIN after approval (not at the moment of the
-- approve click) - closest equivalent here to consultrack's "starts on
-- first real use" principle, since Appointment- already gates all access
-- behind approval (unlike consultrack's self-serve signup).

alter table da_owners add column if not exists trial_started_at timestamptz;
alter table da_owners add column if not exists trial_extended_days int not null default 0;
alter table da_owners add column if not exists is_blocked boolean not null default false;

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

  -- Start the trial clock on first login after approval, not at approve-time.
  -- Never start a trial for the demo account - it must stay accessible forever.
  if v_owner.status = 'approved' and v_owner.trial_started_at is null and v_owner.username <> 'demo_owner' then
    update da_owners set trial_started_at = now() where id = v_owner.id;
    v_owner.trial_started_at := now();
  end if;

  insert into da_owner_sessions (owner_id) values (v_owner.id) returning token into v_token;
  return query select v_token, v_owner.id, v_owner.clinic_group_name, v_owner.owner_name, v_owner.phone, v_owner.email, v_owner.username, v_owner.status, v_owner.broad_category, v_owner.category, v_owner.telegram_chat_id, v_owner.trial_started_at, v_owner.trial_extended_days, v_owner.is_blocked;
end;
$function$;

create or replace function public.da_admin_extend_trial(p_owner_id uuid, p_admin_password text, p_days int)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
begin
  if not da_admin_check_password(p_admin_password) then raise exception 'Unauthorized'; end if;
  if p_days is null or p_days < 1 then raise exception 'Invalid number of days'; end if;
  update da_owners set trial_extended_days = trial_extended_days + p_days where id = p_owner_id;
  return true;
end;
$function$;

create or replace function public.da_admin_set_owner_blocked(p_owner_id uuid, p_admin_password text, p_blocked boolean)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
begin
  if not da_admin_check_password(p_admin_password) then raise exception 'Unauthorized'; end if;
  update da_owners set is_blocked = p_blocked where id = p_owner_id;
  return true;
end;
$function$;

-- da_admin_list_owners already does `select * from da_owners` returning
-- SETOF da_owners, so it automatically picks up the new columns above -
-- no change needed there.

-- da_owner_get_profile is called on every dashboard entry and its result is
-- merged into the client's OWNER object - without these fields, the merge
-- would wipe trial_started_at/trial_extended_days/is_blocked to undefined
-- on every load, defeating the reload-time trial check.
drop function if exists public.da_owner_get_profile(uuid);
create or replace function public.da_owner_get_profile(p_token uuid)
returns table(id uuid, clinic_group_name text, owner_name text, phone text, email text, username text, status text, broad_category text, category text, telegram_chat_id text, trial_started_at timestamptz, trial_extended_days int, is_blocked boolean)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_owner_id uuid;
begin
  v_owner_id := da_require_owner_session(p_token);
  return query select o.id, o.clinic_group_name, o.owner_name, o.phone, o.email, o.username, o.status, o.broad_category, o.category, o.telegram_chat_id, o.trial_started_at, o.trial_extended_days, o.is_blocked from da_owners o where o.id = v_owner_id;
end;
$function$;
