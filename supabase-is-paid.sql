-- Paid-plan flag. Once true, a provider is exempt from all trial-expiry
-- checks everywhere (login block, reload block, reminder emails, banners)
-- and unlocks Export Excel - the one feature held back during trial.

alter table da_owners add column if not exists is_paid boolean not null default false;

create or replace function public.da_admin_set_paid(p_owner_id uuid, p_admin_password text, p_paid boolean)
returns boolean
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
begin
  if not da_admin_check_password(p_admin_password) then raise exception 'Unauthorized'; end if;
  update da_owners set is_paid = p_paid where id = p_owner_id;
  return true;
end;
$function$;

drop function if exists public.da_owner_login(text, text);
create or replace function public.da_owner_login(p_username text, p_password text)
returns table(session_token uuid, id uuid, clinic_group_name text, owner_name text, phone text, email text, username text, status text, broad_category text, category text, telegram_chat_id text, trial_started_at timestamptz, trial_extended_days int, is_blocked boolean, is_paid boolean)
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
  return query select v_token, v_owner.id, v_owner.clinic_group_name, v_owner.owner_name, v_owner.phone, v_owner.email, v_owner.username, v_owner.status, v_owner.broad_category, v_owner.category, v_owner.telegram_chat_id, v_owner.trial_started_at, v_owner.trial_extended_days, v_owner.is_blocked, v_owner.is_paid;
end;
$function$;

drop function if exists public.da_owner_get_profile(uuid);
create or replace function public.da_owner_get_profile(p_token uuid)
returns table(id uuid, clinic_group_name text, owner_name text, phone text, email text, username text, status text, broad_category text, category text, telegram_chat_id text, trial_started_at timestamptz, trial_extended_days int, is_blocked boolean, is_paid boolean)
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $function$
declare v_owner_id uuid;
begin
  v_owner_id := da_require_owner_session(p_token);
  return query select o.id, o.clinic_group_name, o.owner_name, o.phone, o.email, o.username, o.status, o.broad_category, o.category, o.telegram_chat_id, o.trial_started_at, o.trial_extended_days, o.is_blocked, o.is_paid from da_owners o where o.id = v_owner_id;
end;
$function$;
