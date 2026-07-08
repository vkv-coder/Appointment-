# Setup Steps - Appointment App (Multi-Provider Version)

## 1. Supabase (database)
- **If setting up fresh:** Create a NEW Supabase project — **select Mumbai / ap-south-1 region** so data stays in India. Open SQL Editor → paste whole `supabase-schema.sql` → Run.
  (This also creates Doshi Dental Clinics as the first ready-to-use account: username `doshi`, password `doshi123`)
- **If you already ran the schema before (have real data):** Do NOT run `supabase-schema.sql` again — it will delete existing data. Instead run `ALTER-if-already-setup.sql` only (adds the category field).
- Project Settings → API → copy **Project URL** and **anon public key**

## 2. Fill in the code
Open these files and paste your Supabase URL + anon key at the top of each:
- `book.html`
- `dashboard.html`
- `signup.html`
- `admin-approval.html`
- `directory.html`

Also in `admin-approval.html`, change `ADMIN_PASSWORD` to something only you know.

## 3. GitHub Pages
- Create new repo: `appointment` (public)
- Upload all files: `index.html`, `book.html`, `dashboard.html`, `signup.html`, `admin-approval.html`, `directory.html`, `privacy.html`, `manifest.json`, `CNAME`
- Enable GitHub Pages (Settings → Pages → main branch)

**Links you'll use:**
- Home / landing page (choose "I am a User" or "I am a Service Provider"): `appointment.anyapps.in/`
- Public directory (users browse all providers): `appointment.anyapps.in/directory.html`
- New provider sign-up: `appointment.anyapps.in/signup.html`
- Your approval page (only you): `appointment.anyapps.in/admin-approval.html`
- Provider dashboard login: `appointment.anyapps.in/dashboard.html`
- Direct booking link (per provider, skips directory): `appointment.anyapps.in/book.html?owner=THEIR_OWNER_ID`

To find Doshi's owner ID for their direct booking link: Supabase → Table Editor → `da_owners` → copy the `id` value, put it after `?owner=` in the link above.

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
- Each provider can message the bot once to get their own chat ID, or leave blank — alerts fall back to your Telegram (8507770594)

## How the flow works now
1. Homepage (`index.html`) lets someone choose **User** (goes to Directory) or **Service Provider** (Login / Sign Up)
2. New provider fills `signup.html` (category first: Dentist, Psychiatrist, CA, etc., or "Other") → you get notified → approve on `admin-approval.html`
3. They log in at `dashboard.html` → add their own Locations, Providers, weekly schedule (under "Locations & Providers" tab)
4. Users browse `directory.html`, filter by category, tap "Book Now" → lands on that provider's private `book.html?owner=...` page
5. User books → provider confirms in dashboard (or staff books directly via "Add Appointment" tab for phone-in users)
6. Dashboard → "Export Excel" tab downloads confirmed appointments for any date range

Once all above is done, the app is fully live for Doshi and ready for any future provider to sign up.
