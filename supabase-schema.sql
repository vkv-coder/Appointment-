-- ============================================================
-- DR APPOINTMENT - Multi-Clinic Supabase Schema (v2)
-- Run this whole file once in Supabase SQL Editor
-- IMPORTANT: Create/select your Supabase project in the
-- Mumbai (ap-south-1) region so patient data stays in India.
-- ============================================================

-- Drop old single-clinic tables if they exist (v1)
drop table if exists da_appointments cascade;
drop table if exists da_schedule cascade;
drop table if exists da_patients cascade;
drop table if exists da_doctors cascade;
drop table if exists da_clinics cascade;
drop table if exists da_owners cascade;

-- 1. Owners (clinic groups) - each signup = one owner account
create table da_owners (
  id uuid primary key default gen_random_uuid(),
  clinic_group_name text not null,
  owner_name text not null,
  phone text not null,
  email text,
  username text not null unique,
  password text not null,              -- simple plain password (no Supabase Auth used)
  status text not null default 'pending',   -- pending | approved | rejected
  category text,                       -- e.g. Dental, Legal, CA, Physiotherapy
  telegram_chat_id text,
  created_at timestamptz default now()
);

-- 2. Clinics (belongs to an owner)
create table da_clinics (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references da_owners(id) on delete cascade,
  name text not null,
  address text,
  off_days int[] not null default '{}',   -- 0=Sunday .. 6=Saturday
  created_at timestamptz default now()
);

-- 3. Doctors (belongs to an owner)
create table da_doctors (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references da_owners(id) on delete cascade,
  name text not null,
  telegram_chat_id text,
  email text,
  created_at timestamptz default now()
);

-- 4. Weekly schedule (which clinic + session on which day, per doctor)
create table da_schedule (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references da_owners(id) on delete cascade,
  doctor_id uuid references da_doctors(id) on delete cascade,
  clinic_id uuid references da_clinics(id) on delete cascade,
  day_of_week int not null,        -- 0=Sunday .. 6=Saturday
  session text not null,           -- 'morning' | 'evening' | 'both'
  morning_start time default '10:00',
  morning_end time default '13:00',
  evening_start time default '17:00',
  evening_end time default '20:00'
);

-- 5. Patients (belongs to an owner, phone unique within that owner only)
create table da_patients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references da_owners(id) on delete cascade,
  name text not null,
  sex text,
  age int,
  phone text not null,
  email text,
  telegram_id text,
  created_at timestamptz default now(),
  unique(owner_id, phone)
);

-- 6. Appointments
create table da_appointments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references da_owners(id) on delete cascade,
  patient_id uuid references da_patients(id) on delete cascade,
  doctor_id uuid references da_doctors(id),        -- preferred doctor, null = "Any"
  preferred_session text not null,
  preferred_date date not null,
  status text not null default 'pending',          -- pending | confirmed | rejected
  confirmed_doctor_id uuid references da_doctors(id),
  confirmed_clinic_id uuid references da_clinics(id),
  confirmed_date date,
  confirmed_time time,
  booked_by text default 'patient',                -- 'patient' | 'staff'
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- Permissive RLS (no Supabase Auth - app filters by owner_id)
-- ============================================================
alter table da_owners enable row level security;
alter table da_clinics enable row level security;
alter table da_doctors enable row level security;
alter table da_schedule enable row level security;
alter table da_patients enable row level security;
alter table da_appointments enable row level security;

create policy "public read owners" on da_owners for select using (true);
create policy "public insert owners" on da_owners for insert with check (true);
create policy "public update owners" on da_owners for update using (true);

create policy "public read clinics" on da_clinics for select using (true);
create policy "public insert clinics" on da_clinics for insert with check (true);
create policy "public update clinics" on da_clinics for update using (true);
create policy "public delete clinics" on da_clinics for delete using (true);

create policy "public read doctors" on da_doctors for select using (true);
create policy "public insert doctors" on da_doctors for insert with check (true);
create policy "public update doctors" on da_doctors for update using (true);
create policy "public delete doctors" on da_doctors for delete using (true);

create policy "public read schedule" on da_schedule for select using (true);
create policy "public insert schedule" on da_schedule for insert with check (true);
create policy "public update schedule" on da_schedule for update using (true);
create policy "public delete schedule" on da_schedule for delete using (true);

create policy "public read patients" on da_patients for select using (true);
create policy "public insert patients" on da_patients for insert with check (true);
create policy "public update patients" on da_patients for update using (true);

create policy "public read appointments" on da_appointments for select using (true);
create policy "public insert appointments" on da_appointments for insert with check (true);
create policy "public update appointments" on da_appointments for update using (true);

-- ============================================================
-- Seed: Doshi Dental Clinics as the FIRST approved owner account
-- Username: doshi   Password: doshi123  (change after first login)
-- ============================================================
do $$
declare
  owner_id uuid;
  smit_id uuid;
  adinath_id uuid;
  priyanka_id uuid;
  bhaumik_id uuid;
  d int;
begin
  insert into da_owners (clinic_group_name, owner_name, phone, email, username, password, status, category)
  values ('Doshi Dental Clinics', 'Dr. Bhaumik Doshi', '9825230808', 'vkvcoder.support@gmail.com', 'doshi', 'doshi123', 'approved', 'Dental')
  returning id into owner_id;

  insert into da_clinics (owner_id, name, address, off_days) values
  (owner_id, 'Smit Oral Care', 'Adeshwar, Ground Floor, Opp. Kotecha Girls High School, Kotechanagar Main Road, Rajkot', '{0}')
  returning id into smit_id;

  insert into da_clinics (owner_id, name, address, off_days) values
  (owner_id, 'Adinath Dental Care', '1st Floor, Pragati Complex, Dharam Chowk, City Station Road, Wankaner - 363621', '{0,3}')
  returning id into adinath_id;

  insert into da_doctors (owner_id, name) values (owner_id, 'Dr. Priyanka Doshi') returning id into priyanka_id;
  insert into da_doctors (owner_id, name) values (owner_id, 'Dr. Bhaumik Doshi') returning id into bhaumik_id;

  for d in 1..6 loop
    insert into da_schedule (owner_id, doctor_id, clinic_id, day_of_week, session)
    values (owner_id, priyanka_id, smit_id, d, 'both');
  end loop;

  foreach d in array array[1,2,4,5,6] loop
    insert into da_schedule (owner_id, doctor_id, clinic_id, day_of_week, session)
    values (owner_id, bhaumik_id, adinath_id, d, 'morning');
    insert into da_schedule (owner_id, doctor_id, clinic_id, day_of_week, session)
    values (owner_id, bhaumik_id, smit_id, d, 'evening');
  end loop;

  insert into da_schedule (owner_id, doctor_id, clinic_id, day_of_week, session)
  values (owner_id, bhaumik_id, smit_id, 3, 'both');
end $$;

-- Find your owner_id + booking link after running this:
-- select id, clinic_group_name from da_owners;
-- Patient booking link: index.html?owner=<that id>
