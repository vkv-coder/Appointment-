# Setup Steps - Dr. Appointment App (Multi-Clinic Version)

## 1. Supabase (database)
- **If setting up fresh:** Create a NEW Supabase project — **select Mumbai / ap-south-1 region** so data stays in India. Open SQL Editor → paste whole `supabase-schema.sql` → Run.
  (This also creates Doshi Dental Clinics as the first ready-to-use account: username `doshi`, password `doshi123`)
- **If you already ran the schema before (have real data):** Do NOT run `supabase-schema.sql` again — it will delete existing data. Instead run `ALTER-if-already-setup.sql` only (adds the new category field).
- Project Settings → API → copy **Project URL** and **anon public key**

## 2. Fill in the code
Open these files and paste your Supabase URL + anon key at the top of each:
- `index.html`
- `dashboard.html`
- `signup.html`
- `admin-approval.html`
- `directory.html`

Also in `admin-approval.html`, change `ADMIN_PASSWORD` to something only you know.

## 3. GitHub Pages
- Create new repo: `DR-APPOINTMENT` (public)
- Upload all files: `index.html`, `dashboard.html`, `signup.html`, `admin-approval.html`, `directory.html`, `privacy.html`, `manifest.json`, `CNAME`
- Enable GitHub Pages (Settings → Pages → main branch)

**Links you'll use:**
- Public directory (patients browse all doctors/consultants): `appointment.anyapps.in/directory.html`
- New clinic sign-up: `appointment.anyapps.in/signup.html`
- Your approval page (only you): `appointment.anyapps.in/admin-approval.html`
- Clinic dashboard login: `appointment.anyapps.in/dashboard.html`
- Patient booking (per clinic, direct link): `appointment.anyapps.in/index.html?owner=THEIR_OWNER_ID`

To find Doshi's owner ID for their patient link: Supabase → Table Editor → `da_owners` → copy the `id` value, put it after `?owner=` in the link above. Share that exact link with Doshi's patients.

## 4. Google Apps Script (notifications)
- script.google.com → New Project → paste `google-apps-script.gs`
- Fill in SUPABASE_URL, SUPABASE_ANON_KEY, TELEGRAM_BOT_TOKEN
- Deploy → New deployment → Web app → Execute as **Me** → Access **Anyone**
- Copy the deployment URL

## 5. Supabase Webhooks (connects DB to notifications) - set up TWO
Supabase → Database → Webhooks → Create:
1. Table: `da_owners` → Event: Insert → HTTP Request → paste Apps Script URL
2. Table: `da_appointments` → Events: Insert + Update → HTTP Request → paste same Apps Script URL

## 6. Telegram Bot
- Message @BotFather → /newbot → get bot token → paste into `google-apps-script.gs`
- Each doctor/owner can message the bot once to get their own chat ID, or leave blank — alerts fall back to your Telegram (8507770594)

## How the flow works now
1. New doctor fills `signup.html` → you get notified → approve on `admin-approval.html`
2. They log in at `dashboard.html` → add their own clinics, doctors, weekly schedule (under "Clinics & Doctors" tab)
3. You share their unique patient link (`index.html?owner=...`) with their patients
4. Patients book → doctor confirms in dashboard (or staff books directly via "Add Appointment" tab for phone-in patients)
5. Dashboard → "Export Excel" tab downloads confirmed appointments for any date range

Once all above is done, the app is fully live for Doshi and ready for any future clinic to sign up.
