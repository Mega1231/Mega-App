// Pure helpers for caregiver applications (no Firebase calls), so they can
// be unit-tested locally.
const crypto = require("crypto");

const AGENCY_TIME_ZONE = "America/Toronto";

/** Documents every applicant must upload (Becky: all required for everyone). */
const REQUIRED_DOCUMENTS = [
  { id: "id_1", label: "Photo ID #1",
    hint: "Driver's licence, passport, PR card or health card" },
  { id: "id_2", label: "Photo ID #2",
    hint: "A second, different piece of ID" },
  { id: "police_check", label: "Police check",
    hint: "Criminal record check with vulnerable sector search. The receipt is OK if results aren't back yet" },
  { id: "psw_certificate", label: "PSW certificate", hint: "" },
  { id: "work_permit", label: "Work permit", hint: "" },
  { id: "sin", label: "SIN", hint: "SIN letter or card" },
  { id: "tb_test", label: "TB test", hint: "" },
  { id: "cpr_first_aid", label: "CPR / First Aid", hint: "" },
  { id: "aoda", label: "AODA certificate", hint: "" },
];
const DOCUMENT_IDS = new Set(REQUIRED_DOCUMENTS.map((d) => d.id));

/** Statuses where the applicant still has something to do. */
const OPEN_STATUSES = new Set(["invited", "in_progress", "needs_changes"]);

const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
const ALLOWED_TYPES = new Set([
  "image/jpeg", "image/png", "image/heic", "image/heif", "image/webp",
  "application/pdf",
]);

// ── Tokens & passwords ──

function newToken() {
  return crypto.randomBytes(24).toString("base64url");
}

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

function hashPassword(password, salt = crypto.randomBytes(16).toString("hex")) {
  const hash = crypto.scryptSync(String(password), salt, 64).toString("hex");
  return { salt, hash };
}

function verifyPassword(password, salt, hash) {
  const candidate = crypto.scryptSync(String(password), salt, 64);
  const stored = Buffer.from(hash, "hex");
  return stored.length === candidate.length &&
    crypto.timingSafeEqual(stored, candidate);
}

/** Short-lived "documents unlocked" token bound to one admin uid. */
function signVaultToken(uid, secret, now = Date.now(), ttlMs = 30 * 60 * 1000) {
  const exp = now + ttlMs;
  const sig = crypto.createHmac("sha256", secret).update(`${uid}.${exp}`)
    .digest("base64url");
  return `${exp}.${sig}`;
}

function verifyVaultToken(token, uid, secret, now = Date.now()) {
  const [expText, sig] = String(token || "").split(".");
  const exp = Number(expText);
  if (!exp || !sig || exp < now) return false;
  const expected = crypto.createHmac("sha256", secret).update(`${uid}.${exp}`)
    .digest("base64url");
  return sig.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
}

// ── Validation ──

const trim = (v) => (typeof v === "string" ? v.trim() : "");
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function cleanContact(c) {
  return {
    name: trim(c?.name), relation: trim(c?.relation),
    phone: trim(c?.phone), email: trim(c?.email),
  };
}

/** Normalises the details form and lists what's still missing. */
function normalizeDetails(input) {
  const details = {
    fullName: trim(input?.fullName),
    email: trim(input?.email),
    phone: trim(input?.phone),
    emergency: cleanContact(input?.emergency),
    references: [0, 1].map((i) => cleanContact(input?.references?.[i])),
  };
  const missing = [];
  if (!details.fullName) missing.push("Full name");
  if (!EMAIL_RE.test(details.email)) missing.push("Your email");
  if (!details.phone) missing.push("Your phone number");
  const contactMissing = (c, label) => {
    if (!c.name) missing.push(`${label} name`);
    if (!c.relation) missing.push(`${label} relationship`);
    if (!c.phone) missing.push(`${label} phone`);
    if (!EMAIL_RE.test(c.email)) missing.push(`${label} email`);
  };
  contactMissing(details.emergency, "Emergency contact");
  details.references.forEach((r, i) => contactMissing(r, `Reference ${i + 1}`));
  return { details, missing };
}

/** What blocks submission: missing details or documents not yet uploaded. */
function submissionProblems(app) {
  const problems = [...normalizeDetails(app.details || {}).missing];
  for (const d of REQUIRED_DOCUMENTS) {
    const doc = app.documents?.[d.id];
    if (!doc || doc.status === "missing" || !doc.storagePath) {
      problems.push(d.label);
    } else if (doc.status === "needs_changes") {
      problems.push(`${d.label} (needs a new upload)`);
    }
  }
  return problems;
}

function safeFileName(name) {
  const base = String(name || "file").split(/[\\/]/).pop();
  return base.replace(/[^A-Za-z0-9._-]+/g, "_").slice(-80) || "file";
}

// ── Reminders ──

/** Hour (0–23) in the agency time zone. */
function zonedHour(date, timeZone = AGENCY_TIME_ZONE) {
  return Number(new Intl.DateTimeFormat("en-US", {
    timeZone, hour: "2-digit", hourCycle: "h23",
  }).format(date));
}

/**
 * Whether an applicant should get a reminder now: still has work to do,
 * has an email, it's 8 am–10 pm in Toronto, it's been ≥ 4 hours since the
 * invite / last reminder / their last activity, the invite is under
 * 14 days old, and the admin hasn't turned reminders off.
 */
function shouldRemind(app, now = new Date()) {
  if (!OPEN_STATUSES.has(app.status) || app.remindersOff ||
      !EMAIL_RE.test(app.email || "")) {
    return false;
  }
  const hour = zonedHour(now);
  if (hour < 8 || hour >= 22) return false;
  const ms = (t) => (t?.toDate ? t.toDate() : t ? new Date(t) : null)?.getTime();
  const created = ms(app.invitedAt || app.createdAt);
  if (!created || now.getTime() - created > 14 * 24 * 3600 * 1000) return false;
  const last = Math.max(created, ms(app.lastReminderAt) || 0,
    ms(app.lastApplicantActivityAt) || 0);
  return now.getTime() - last >= 4 * 3600 * 1000 - 5 * 60 * 1000;
}

function escapeHtml(text) {
  return String(text ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;",
  })[c]);
}

module.exports = {
  AGENCY_TIME_ZONE,
  EMAIL_RE,
  escapeHtml,
  REQUIRED_DOCUMENTS,
  DOCUMENT_IDS,
  OPEN_STATUSES,
  MAX_UPLOAD_BYTES,
  ALLOWED_TYPES,
  newToken,
  hashToken,
  hashPassword,
  verifyPassword,
  signVaultToken,
  verifyVaultToken,
  normalizeDetails,
  submissionProblems,
  safeFileName,
  zonedHour,
  shouldRemind,
};
