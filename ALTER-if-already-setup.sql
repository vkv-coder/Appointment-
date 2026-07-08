-- ============================================================
-- RUN THIS INSTEAD of supabase-schema.sql if you have ALREADY
-- set up your database before (has real patients/appointments).
-- Running the full supabase-schema.sql again will DELETE all
-- existing data. This small command just adds the new column.
-- ============================================================

alter table da_owners add column if not exists category text;

-- Optional: set Doshi's category so it shows correctly in the directory
update da_owners set category = 'Dental' where username = 'doshi';
