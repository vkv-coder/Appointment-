// ============================================================
// DR APPOINTMENT - Notification Relay (v2, multi-clinic)
// Deploy this as a Web App (Execute as: Me, Access: Anyone)
// Paste the deployment URL into TWO Supabase Database Webhooks:
//   1. Table: da_owners       Events: Insert
//   2. Table: da_appointments Events: Insert, Update
// ============================================================

const SUPABASE_URL = "PASTE_SUPABASE_URL_HERE";
const SUPABASE_ANON_KEY = "PASTE_SUPABASE_ANON_KEY_HERE";

const TELEGRAM_BOT_TOKEN = "PASTE_TELEGRAM_BOT_TOKEN_HERE";  // from @BotFather
const VIJAY_TELEGRAM_CHAT_ID = "8507770594";
const SUPPORT_EMAIL = "vkvcoder.support@gmail.com";
const ADMIN_APPROVAL_URL = "https://appointment.anyapps.in/admin-approval.html";
const DASHBOARD_URL = "https://appointment.anyapps.in/dashboard.html";

function doPost(e) {
  try {
    const payload = JSON.parse(e.postData.contents);

    if (payload.table === "da_owners" && payload.type === "INSERT") {
      handleNewOwnerSignup(payload.record);
    } else if (payload.table === "da_appointments") {
      if (payload.type === "INSERT") {
        handleNewRequest(payload.record);
      } else if (payload.type === "UPDATE") {
        const wasConfirmed = payload.old_record && payload.old_record.status === "confirmed";
        const isConfirmed = payload.record.status === "confirmed";
        if (isConfirmed && !wasConfirmed) handleConfirmed(payload.record);
      }
    }

    return ContentService.createTextOutput("ok");
  } catch (err) {
    return ContentService.createTextOutput("error: " + err.message);
  }
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

// ---------- new clinic sign-up -> notify Vijay ----------
function handleNewOwnerSignup(record) {
  const text =
    `🆕 New Clinic Sign-up\n` +
    `Clinic: ${record.clinic_group_name}\n` +
    `Owner: ${record.owner_name}\n` +
    `Phone: ${record.phone}\n` +
    `Username: ${record.username}\n\n` +
    `Approve here: ${ADMIN_APPROVAL_URL}`;

  sendTelegram(VIJAY_TELEGRAM_CHAT_ID, text);
  MailApp.sendEmail(SUPPORT_EMAIL, "New Clinic Sign-up - " + record.clinic_group_name, text);
}

// ---------- new pending appointment request -> notify doctor/owner ----------
function handleNewRequest(record) {
  const patient = sbGet("da_patients", "id", record.patient_id);
  const doctor = record.doctor_id ? sbGet("da_doctors", "id", record.doctor_id) : null;
  const owner = sbGet("da_owners", "id", record.owner_id);
  const doctorLabel = doctor ? doctor.name : "Any Doctor";

  const text =
    `🦷 New Appointment Request - ${owner ? owner.clinic_group_name : ""}\n` +
    `Patient: ${patient ? patient.name : "Unknown"}\n` +
    `Phone: ${patient ? patient.phone : "-"}\n` +
    `Preferred: ${record.preferred_date} (${record.preferred_session})\n` +
    `Doctor: ${doctorLabel}\n\n` +
    `Confirm here: ${DASHBOARD_URL}`;

  const doctorChatId = doctor && doctor.telegram_chat_id ? doctor.telegram_chat_id : (owner && owner.telegram_chat_id ? owner.telegram_chat_id : VIJAY_TELEGRAM_CHAT_ID);
  sendTelegram(doctorChatId, text);

  const emailTo = (doctor && doctor.email) ? doctor.email : (owner && owner.email ? owner.email : SUPPORT_EMAIL);
  MailApp.sendEmail(emailTo, "New Appointment Request - " + doctorLabel, text);
}

// ---------- confirmed appointment -> notify patient ----------
function handleConfirmed(record) {
  const patient = sbGet("da_patients", "id", record.patient_id);
  const doctor = sbGet("da_doctors", "id", record.confirmed_doctor_id);
  const clinic = sbGet("da_clinics", "id", record.confirmed_clinic_id);

  const text =
    `✅ Appointment Confirmed\n` +
    `Doctor: ${doctor ? doctor.name : "-"}\n` +
    `Clinic: ${clinic ? clinic.name : "-"}\n` +
    `Address: ${clinic ? clinic.address : "-"}\n` +
    `Date: ${record.confirmed_date}\n` +
    `Time: ${record.confirmed_time}`;

  if (patient && patient.telegram_id) sendTelegram(patient.telegram_id, text);
  if (patient && patient.email) MailApp.sendEmail(patient.email, "Your Dental Appointment is Confirmed", text);
}

function sendTelegram(chatId, text) {
  if (!chatId || !TELEGRAM_BOT_TOKEN || TELEGRAM_BOT_TOKEN.indexOf("PASTE") === 0) return;
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
  UrlFetchApp.fetch(url, {
    method: "post",
    payload: { chat_id: chatId, text: text },
    muteHttpExceptions: true
  });
}
