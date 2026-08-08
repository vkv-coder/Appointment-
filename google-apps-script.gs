// ============================================================
// DR APPOINTMENT - Notification Relay (v3, multi-clinic)
// Deploy this as a Web App (Execute as: Me, Access: Anyone)
// Paste the deployment URL into TWO Supabase Database Webhooks:
//   1. Table: da_owners       Events: Insert, Update   <-- Update added in v3;
//      if your existing webhook is still Insert-only, edit it in Supabase
//      Studio (Database -> Webhooks) to add Update, or owner approval/
//      rejection emails below will never fire.
//   2. Table: da_appointments Events: Insert, Update
//
// Also add a time-driven trigger for sendTrialEndingReminders (daily) -
// see the comment on that function below for exact steps.
// ============================================================

const SUPABASE_URL = "https://jqqnnkzozjskziaizajg.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxcW5ua3pvempza3ppYWl6YWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5Mjk1ODAsImV4cCI6MjA4ODUwNTU4MH0.sEYeWnm0dvuw8bLSVnQhqmgV8LB-pELjpuVIa3Us1Gg";

// Set via: Project Settings (gear icon) -> Script Properties -> Add script property
// -> Property: TELEGRAM_BOT_TOKEN, Value: <the bot token>
function getTelegramBotToken() {
  return PropertiesService.getScriptProperties().getProperty("TELEGRAM_BOT_TOKEN");
}

const VIJAY_TELEGRAM_CHAT_ID = "8507770594";
const SUPPORT_EMAIL = "vkvcoder.support@gmail.com";
const ADMIN_APPROVAL_URL = "https://appointment.anyapps.in/admin-approval.html";
const DASHBOARD_URL = "https://appointment.anyapps.in/dashboard.html";

// Fixed demo clinic owner (re-seeded nightly by reset_appointment_demo) -
// its INSERT/UPDATE events must never page real Telegram/email.
const DEMO_OWNER_ID = "a539635d-7c40-4f83-ae7c-7c517472bb1c";

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);

    // Telegram sends updates with a "message" field - reply with their Chat ID
    if (payload.message) {
      handleTelegramMessage(payload.message);
      return HtmlService.createHtmlOutput("ok");
    }

    if (payload.record && payload.record.owner_id === DEMO_OWNER_ID) {
      return HtmlService.createHtmlOutput("ok"); // skip demo-reset noise
    }

    if (payload.table === "da_owners") {
      if (payload.type === "INSERT") {
        handleNewOwnerSignup(payload.record);
      } else if (payload.type === "UPDATE") {
        const oldStatus = payload.old_record && payload.old_record.status;
        const newStatus = payload.record.status;
        if (newStatus !== oldStatus && (newStatus === "approved" || newStatus === "rejected")) {
          handleOwnerStatusChange(payload.record, newStatus);
        }
        const hadNoTrial = payload.old_record && !payload.old_record.trial_started_at;
        if (hadNoTrial && payload.record.trial_started_at) {
          handleTrialStarted(payload.record);
        }
      }
    } else if (payload.table === "da_appointments") {
      if (payload.type === "INSERT") {
        if (payload.record.status === "confirmed") {
          handleConfirmed(payload.record, true);   // instant-booked
        } else {
          handleNewRequest(payload.record);
        }
      } else if (payload.type === "UPDATE") {
        const wasConfirmed = payload.old_record && payload.old_record.status === "confirmed";
        const isConfirmed = payload.record.status === "confirmed";
        const wasRejected = payload.old_record && payload.old_record.status === "rejected";
        const isRejected = payload.record.status === "rejected";
        if (isConfirmed && !wasConfirmed) handleConfirmed(payload.record, false);
        // Assumed status value is "rejected" (matches da_owner_reject_appointment's
        // naming and admin-approval.html's owner-status convention) - if the actual
        // column uses a different string, adjust this check to match.
        if (isRejected && !wasRejected) handleAppointmentRejected(payload.record);
      }
    }

    return HtmlService.createHtmlOutput("ok");
  } catch (err) {
    return HtmlService.createHtmlOutput("error: " + err.message);
  }
}

// ---------- Telegram: reply with the sender's Chat ID so they can copy it ----------
function handleTelegramMessage(message) {
  const chatId = message.chat.id;
  const text =
    `Your Telegram Chat ID is:\n\n${chatId}\n\n` +
    `Copy this and paste it into your Appointment app - either during sign-up or in your Dashboard - to receive free instant alerts.`;
  sendTelegram(chatId, text);
}

// ---------- format yyyy-mm-dd as dd-mm-yyyy for messages ----------
function fmtDate(iso) {
  if (!iso) return "";
  const parts = iso.split("-");
  return parts.length === 3 ? `${parts[2]}-${parts[1]}-${parts[0]}` : iso;
}

// ---------- helper: fetch a single row from Supabase ----------
function sbGet(table, filterCol, filterVal) {
  const url = `${SUPABASE_URL}/rest/v1/${table}?${filterCol}=eq.${filterVal}&select=*`;
  const res = UrlFetchApp.fetch(url, {
    headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + SUPABASE_ANON_KEY },
    muteHttpExceptions: true
  });
  const data = JSON.parse(res.getContentText());
  return data && data.length ? data[0] : null;
}

// ---------- send an email without letting a failure here (bad address, quota)
// block whatever notification runs next in the same handler ----------
function safeEmail(to, subject, body) {
  if (!to) return;
  try {
    MailApp.sendEmail(to, subject, body);
  } catch (e) {
    Logger.log("Email to " + to + " failed: " + e.message);
  }
}

// ---------- new clinic sign-up -> notify Vijay (no approval needed - just an FYI) ----------
function handleNewOwnerSignup(record) {
  const text =
    `🆕 New Provider Sign-up (auto-active, 30-day free trial)\n` +
    `Organisation: ${record.clinic_group_name}\n` +
    `Owner: ${record.owner_name}\n` +
    `Phone: ${record.phone}\n` +
    `Username: ${record.username}\n\n` +
    `View/manage: ${ADMIN_APPROVAL_URL}`;

  sendTelegram(VIJAY_TELEGRAM_CHAT_ID, text);
  safeEmail(SUPPORT_EMAIL, "New Provider Sign-up - " + record.clinic_group_name, text);
}

// ---------- owner's free trial has actually started (first clinic/doctor added) -> notify Vijay ----------
function handleTrialStarted(record) {
  const text =
    `🎯 Free trial started\n` +
    `Organisation: ${record.clinic_group_name}\n` +
    `Owner: ${record.owner_name}\n` +
    `Phone: ${record.phone}\n\n` +
    `30-day trial clock is now running for this provider.`;

  sendTelegram(VIJAY_TELEGRAM_CHAT_ID, text);
}

// ---------- owner sign-up approved/rejected -> notify the owner ----------
function handleOwnerStatusChange(record, newStatus) {
  const approved = newStatus === "approved";
  const text = approved
    ? `🎉 Your provider account for "${record.clinic_group_name}" has been approved!\n\n` +
      `Log in to your dashboard: ${DASHBOARD_URL}\n` +
      `Username: ${record.username}`
    : `Your provider sign-up for "${record.clinic_group_name}" was not approved this time.\n\n` +
      `Questions? Contact ${SUPPORT_EMAIL}`;

  if (record.telegram_chat_id) sendTelegram(record.telegram_chat_id, text);
  safeEmail(record.email, "Your Appointment provider account — " + (approved ? "Approved" : "Update"), text);
}

// ---------- new pending appointment request -> notify doctor/owner ----------
function handleNewRequest(record) {
  const patient = sbGet("da_patients", "id", record.patient_id);
  const doctor = record.doctor_id ? sbGet("da_doctors", "id", record.doctor_id) : null;
  const owner = sbGet("da_owners", "id", record.owner_id);
  const doctorLabel = doctor ? doctor.name : "Any Provider";

  const text =
    `🦷 New Appointment Request - ${owner ? owner.clinic_group_name : ""}\n` +
    `Patient: ${patient ? patient.name : "Unknown"}\n` +
    `Phone: ${patient ? patient.phone : "-"}\n` +
    `Preferred: ${fmtDate(record.preferred_date)} (${record.preferred_session})\n` +
    `Provider: ${doctorLabel}\n\n` +
    `Confirm here: ${DASHBOARD_URL}`;

  const doctorChatId = doctor && doctor.telegram_chat_id ? doctor.telegram_chat_id : (owner && owner.telegram_chat_id ? owner.telegram_chat_id : VIJAY_TELEGRAM_CHAT_ID);
  sendTelegramMulti(doctorChatId, text);

  const emailTo = (doctor && doctor.email) ? doctor.email : (owner && owner.email ? owner.email : SUPPORT_EMAIL);
  safeEmail(emailTo, "New Appointment Request - " + doctorLabel, text);
}

// ---------- appointment rejected -> notify the patient ----------
function handleAppointmentRejected(record) {
  const patient = sbGet("da_patients", "id", record.patient_id);
  if (!patient) return;

  const text =
    `Your appointment request for ${fmtDate(record.preferred_date)} (${record.preferred_session}) ` +
    `could not be accommodated this time.\n\n` +
    `Please try requesting a different date, or contact the clinic directly.`;

  if (patient.telegram_id) sendTelegram(patient.telegram_id, text);
  safeEmail(patient.email, "Your Appointment Request — Update", text);
}

// ---------- confirmed appointment -> notify user (and provider if instant-booked) ----------
function handleConfirmed(record, isInstant) {
  const patient = sbGet("da_patients", "id", record.patient_id);
  const doctor = sbGet("da_doctors", "id", record.confirmed_doctor_id);
  const clinic = sbGet("da_clinics", "id", record.confirmed_clinic_id);

  const text =
    `✅ Appointment Confirmed\n` +
    `Provider: ${doctor ? doctor.name : "-"}\n` +
    `Location: ${clinic ? clinic.name : "-"}\n` +
    `Address: ${clinic ? clinic.address : "-"}\n` +
    `Date: ${fmtDate(record.confirmed_date)}\n` +
    `Time: ${record.confirmed_time}`;

  if (patient && patient.telegram_id) sendTelegram(patient.telegram_id, text);
  if (patient && patient.email) safeEmail(patient.email, "Your Appointment is Confirmed", text);

  if (isInstant) {
    const owner = sbGet("da_owners", "id", record.owner_id);
    const providerText =
      `⚡ Instant Booking\n` +
      `Patient: ${patient ? patient.name : "-"} (${patient ? patient.phone : "-"})\n` +
      `Provider: ${doctor ? doctor.name : "-"}\n` +
      `Location: ${clinic ? clinic.name : "-"}\n` +
      `Date: ${fmtDate(record.confirmed_date)}  Time: ${record.confirmed_time}`;
    const chatId = doctor && doctor.telegram_chat_id ? doctor.telegram_chat_id : (owner && owner.telegram_chat_id ? owner.telegram_chat_id : VIJAY_TELEGRAM_CHAT_ID);
    sendTelegramMulti(chatId, providerText);
    const emailTo = (doctor && doctor.email) ? doctor.email : (owner && owner.email ? owner.email : SUPPORT_EMAIL);
    safeEmail(emailTo, "Instant Booking - " + (doctor ? doctor.name : ""), providerText);
  }
}

function sendTelegram(chatId, text) {
  const botToken = getTelegramBotToken();
  if (!chatId || !botToken) {
    return;
  }
  const url = `https://api.telegram.org/bot${botToken}/sendMessage`;
  const response = UrlFetchApp.fetch(url, {
    method: "post",
    contentType: "application/x-www-form-urlencoded",
    payload: { chat_id: String(chatId), text: text },
    muteHttpExceptions: true
  });
}

// Sends to one or more chat IDs given as a comma-separated string (e.g. "111, 222")
function sendTelegramMulti(chatIdsStr, text) {
  if (!chatIdsStr) return;
  String(chatIdsStr).split(",").map(s => s.trim()).filter(Boolean).forEach(id => sendTelegram(id, text));
}

// ---------- helper: PATCH a row in Supabase ----------
function sbPatch(table, filterCol, filterVal, body) {
  const url = `${SUPABASE_URL}/rest/v1/${table}?${filterCol}=eq.${filterVal}`;
  UrlFetchApp.fetch(url, {
    method: "patch",
    contentType: "application/json",
    headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + SUPABASE_ANON_KEY },
    payload: JSON.stringify(body),
    muteHttpExceptions: true
  });
}

// ============================================================
// TRIAL-ENDING REMINDER - scheduled, run daily
// TRIGGER SETUP (one time):
//   GAS -> Triggers (clock icon, left sidebar) -> + Add Trigger
//   Function: sendTrialEndingReminders
//   Event source: Time-driven -> Day timer -> pick any time (e.g. 9am-10am)
//   Save
// Sends the owner (not just Vijay) a heads-up exactly 3 days before their
// 30-day trial ends, once per trial window (trial_reminder_sent guards
// against re-sending daily for all 3 days; da_admin_extend_trial resets
// it so an extended trial gets its own fresh reminder later).
// ============================================================
function sendTrialEndingReminders() {
  try {
    const url = `${SUPABASE_URL}/rest/v1/da_owners?status=eq.approved&is_blocked=eq.false&trial_reminder_sent=eq.false&trial_started_at=not.is.null&select=id,clinic_group_name,owner_name,email,telegram_chat_id,trial_started_at,trial_extended_days&id=neq.${DEMO_OWNER_ID}`;
    const res = UrlFetchApp.fetch(url, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + SUPABASE_ANON_KEY },
      muteHttpExceptions: true
    });
    const owners = JSON.parse(res.getContentText());
    if (!owners || !owners.length) return;

    const TRIAL_DAYS = 30;
    const now = new Date();

    owners.forEach(o => {
      const start = new Date(o.trial_started_at);
      const totalDays = TRIAL_DAYS + (o.trial_extended_days || 0);
      const end = new Date(start.getTime() + totalDays * 86400000);
      const daysLeft = Math.ceil((end - now) / 86400000);

      if (daysLeft === 3) {
        const text =
          `⏳ Your free trial ends in 3 days\n\n` +
          `Your 30-day free trial for "${o.clinic_group_name}" ends on ${fmtDate(end.toISOString().slice(0,10))}.\n\n` +
          `Contact ${SUPPORT_EMAIL} to extend your trial or move to a paid plan and keep your dashboard running without interruption.`;

        if (o.telegram_chat_id) sendTelegramMulti(o.telegram_chat_id, text);
        safeEmail(o.email, "Your Appointment free trial ends in 3 days", text);

        sbPatch("da_owners", "id", o.id, { trial_reminder_sent: true });
      }
    });
  } catch (err) {
    Logger.log("sendTrialEndingReminders error: " + err.message);
  }
}
