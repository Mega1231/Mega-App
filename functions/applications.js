// Caregiver applications (onboarding stage 1): Becky creates an application
// and shares its link; the applicant fills in their details and uploads the
// required documents without logging in; Becky reviews each document,
// requests changes or accepts. The `applications` and `app_secrets`
// collections and the applicant bucket are server-only — everything goes
// through these functions.
const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const nodemailer = require("nodemailer");
const L = require("./applications_logic");
const O = require("./onboarding_letters");

const SMTP_PASSWORD = defineSecret("SMTP_PASSWORD");
const SMTP_USER = "megahomecare0@gmail.com";
const APPLICANT_BUCKET = "mega-h-applicants"; // Toronto region, no client access
const APPLY_BASE_URL = "https://mega-h.web.app/apply/";

const db = () => admin.firestore();
const apps = () => db().collection("applications");
const vaultRef = () => db().collection("app_secrets").doc("documents_vault");
const bucket = () => admin.storage().bucket(APPLICANT_BUCKET);
const now = () => Timestamp.now();

const uploadOptions = { memory: "512MiB", timeoutSeconds: 120 };
const emailOptions = { secrets: [SMTP_PASSWORD] };

// ── Helpers ──

const linkFor = (token) => `${APPLY_BASE_URL}${token}`;

function log(by, action, text = "") {
  return { by, action, text, at: now() };
}

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in.");
  }
  const user = await db().collection("users").doc(request.auth.uid).get();
  const data = user.data();
  if (!data || data.role !== "admin" || data.isActive === false) {
    throw new HttpsError("permission-denied", "Admins only.");
  }
  return { uid: request.auth.uid, name: data.fullName || data.name || "Admin" };
}

async function findByToken(token) {
  if (typeof token !== "string" || token.length < 20) {
    throw new HttpsError("not-found", "This link is not valid.");
  }
  const snap = await apps().where("tokenHash", "==", L.hashToken(token))
    .limit(1).get();
  if (snap.empty) {
    throw new HttpsError("not-found",
      "This link is not valid any more. Please ask Mega Homecare for a new one.");
  }
  return snap.docs[0];
}

function requireOpen(app) {
  if (!L.OPEN_STATUSES.has(app.status)) {
    throw new HttpsError("failed-precondition",
      app.status === "submitted"
        ? "Your application has been submitted and is being reviewed."
        : "This application is closed.");
  }
}

/** What the applicant may see: no storage paths, no admin-only fields. */
function applicantView(app) {
  const documents = {};
  for (const d of L.REQUIRED_DOCUMENTS) {
    const doc = app.documents?.[d.id] || {};
    documents[d.id] = {
      status: doc.status || "missing",
      fileName: doc.fileName || "",
      comment: doc.status === "needs_changes" ? doc.comment || "" : "",
      uploadedAt: doc.uploadedAt?.toMillis?.() || null,
    };
  }
  return {
    fullName: app.fullName || "",
    email: app.email || "",
    status: app.status,
    details: app.details || {},
    documents,
    generalComment: app.status === "needs_changes" ? app.generalComment || "" : "",
    requiredDocuments: L.REQUIRED_DOCUMENTS,
    problems: L.submissionProblems(app),
    onboarding: applicantOnboarding(app),
  };
}

/** Letters to read and sign, once Becky has sent them. */
function applicantOnboarding(app) {
  const ob = app.onboarding;
  if (app.status !== "accepted" || !ob || !["sent", "completed"].includes(ob.status)) {
    return null;
  }
  return {
    status: ob.status,
    hasSignature: Boolean(ob.signaturePath),
    loginCreated: Boolean(app.caregiverUid),
    copiesEmailed: Boolean(ob.copiesEmailedAt),
    letters: O.buildLetters(ob.fields).map((l) => ({
      id: l.id,
      title: l.title,
      heading: l.heading,
      blocks: l.blocks,
      signedAt: ob.letters?.[l.id]?.signedAt?.toMillis?.() || null,
    })),
  };
}

const millis = (t) => t?.toMillis?.() ?? null;

/** Full record for the admin panel (timestamps as millis). */
function adminView(id, app) {
  const documents = {};
  for (const d of L.REQUIRED_DOCUMENTS) {
    const doc = app.documents?.[d.id] || {};
    documents[d.id] = {
      status: doc.status || "missing",
      fileName: doc.fileName || "",
      contentType: doc.contentType || "",
      size: doc.size || 0,
      comment: doc.comment || "",
      uploadedAt: millis(doc.uploadedAt),
      reviewedAt: millis(doc.reviewedAt),
      reviewedBy: doc.reviewedBy || "",
      history: (doc.history || []).map((h) => ({
        fileName: h.fileName || "",
        storagePath: h.storagePath || "",
        status: h.status || "",
        comment: h.comment || "",
        uploadedAt: millis(h.uploadedAt),
        replacedAt: millis(h.replacedAt),
      })),
    };
  }
  return {
    id,
    fullName: app.fullName || "",
    email: app.email || "",
    status: app.status,
    link: app.token ? linkFor(app.token) : "",
    details: app.details || {},
    documents,
    generalComment: app.generalComment || "",
    activity: (app.activity || []).map((a) => ({ ...a, at: millis(a.at) })),
    remindersOff: app.remindersOff === true,
    reminderCount: app.reminderCount || 0,
    lastReminderAt: millis(app.lastReminderAt),
    createdAt: millis(app.createdAt),
    invitedAt: millis(app.invitedAt),
    submittedAt: millis(app.submittedAt),
    decidedAt: millis(app.decidedAt),
    lastApplicantActivityAt: millis(app.lastApplicantActivityAt),
    problems: L.submissionProblems(app),
    onboarding: adminOnboarding(app),
  };
}

function adminOnboarding(app) {
  const ob = app.onboarding || {};
  return {
    status: ob.status || "not_sent",
    fields: ob.fields || null,
    sentAt: millis(ob.sentAt),
    completedAt: millis(ob.completedAt),
    letters: O.buildLetters(ob.fields || O.normalizeFields({}).fields).map((l) => ({
      id: l.id,
      title: l.title,
      signedAt: millis(ob.letters?.[l.id]?.signedAt),
    })),
    caregiverUid: app.caregiverUid || "",
    caregiverUsername: app.caregiverUsername || "",
    defaults: {
      position: O.DEFAULT_POSITION,
      jobDescription: O.DEFAULT_JOB_DESCRIPTION,
    },
  };
}

// ── Email ──

let transport;
function mailer() {
  transport ??= nodemailer.createTransport({
    service: "gmail",
    auth: { user: SMTP_USER, pass: SMTP_PASSWORD.value() },
  });
  return transport;
}

function emailHtml(paragraphs, link, button = "Open my application") {
  const body = paragraphs.map((p) =>
    `<p style="margin:0 0 14px">${p}</p>`).join("");
  const action = link
    ? `<p style="margin:22px 0"><a href="${L.escapeHtml(link)}" ` +
      "style=\"background:#1f6feb;color:#fff;padding:12px 22px;" +
      "border-radius:8px;text-decoration:none;font-weight:600\">" +
      `${L.escapeHtml(button)}</a></p>` +
      `<p style="margin:0 0 14px;font-size:13px;color:#555">Or copy this link: ` +
      `${L.escapeHtml(link)}</p>`
    : "";
  return "<div style=\"font-family:Arial,sans-serif;font-size:15px;" +
    "color:#222;max-width:560px\">" + body + action +
    "<p style=\"margin:22px 0 0\">Thank you,<br>Mega Homecare Inc.</p></div>";
}

/** Sends an email; returns false (and logs) instead of throwing. */
async function sendEmail(to, subject, paragraphs, link, button, attachments) {
  if (!L.EMAIL_RE.test(to || "")) return false;
  try {
    await mailer().sendMail({
      from: `"Mega Homecare" <${SMTP_USER}>`,
      to,
      subject,
      html: emailHtml(paragraphs, link, button),
      ...(attachments ? { attachments } : {}),
    });
    return true;
  } catch (e) {
    logger.error("Email failed", { to, subject, error: e.message });
    return false;
  }
}

const firstName = (app) => L.escapeHtml((app.fullName || "").split(/\s+/)[0] || "there");

function inviteEmail(app, token) {
  return sendEmail(app.email, "Mega Homecare – complete your application", [
    `Hi ${firstName(app)},`,
    "Thank you for your interest in working with Mega Homecare. Please use " +
      "the link below to fill in your details and upload your documents. " +
      "You can take photos with your phone camera.",
    "Documents needed: " + L.REQUIRED_DOCUMENTS.map((d) => d.label).join(", ") + ".",
  ], linkFor(token));
}

function lettersEmail(app, reminder) {
  const left = O.LETTER_IDS.filter((id) => !app.onboarding?.letters?.[id]?.signedAt)
    .length;
  return sendEmail(app.email,
    reminder
      ? "Reminder: please sign your Mega Homecare onboarding documents"
      : "Welcome to Mega Homecare – please sign your onboarding documents",
    [
      `Hi ${firstName(app)},`,
      reminder
        ? `You still have ${left} onboarding document${left === 1 ? "" : "s"} to sign.`
        : "Congratulations, your application has been accepted! Please read " +
          "and sign your 5 onboarding documents: Offer Letter, Welcome Letter, " +
          "Phone Usage Policy, Shift Report Guidelines and Communication " +
          "Compliance. You sign with your finger on your phone.",
    ],
    linkFor(app.token), "Open my documents");
}

function missingList(app) {
  const problems = L.submissionProblems(app);
  if (problems.length === 0) return "Everything is filled in — just press Submit.";
  return "Still needed: " + problems.map(L.escapeHtml).join(", ") + ".";
}

// ── Admin push ──

async function notifyAdmins(title, body, data = {}) {
  const snap = await db().collection("users").where("role", "==", "admin").get();
  const tokens = snap.docs.map((d) => d.data())
    .filter((u) => u.isActive !== false && typeof u.fcmToken === "string" &&
      u.fcmToken)
    .map((u) => u.fcmToken);
  if (tokens.length === 0) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { type: "application", chatId: "", callId: "", ...data },
    android: {
      priority: "high",
      notification: { channelId: "messages_channel", sound: "default" },
    },
    apns: { payload: { aps: { sound: "default" } } },
  }).catch((e) => logger.error("Admin push failed", e));
}

// ── Applicant (public, link token) ──

exports.applicationGet = onCall(async (request) => {
  const doc = await findByToken(request.data?.token);
  const app = doc.data();
  if (!app.firstOpenedAt) {
    await doc.ref.update({ firstOpenedAt: now() });
  }
  return applicantView(app);
});

exports.applicationSaveDetails = onCall(async (request) => {
  const doc = await findByToken(request.data?.token);
  const app = doc.data();
  requireOpen(app);
  const { details, missing } = L.normalizeDetails(request.data?.details);
  const update = {
    details,
    lastApplicantActivityAt: now(),
    updatedAt: now(),
  };
  if (details.fullName) update.fullName = details.fullName;
  if (L.EMAIL_RE.test(details.email)) update.email = details.email;
  if (app.status === "invited") update.status = "in_progress";
  await doc.ref.update(update);
  return { missing, ...applicantView({ ...app, ...update }) };
});

exports.applicationUpload = onCall(uploadOptions, async (request) => {
  const { token, docType, fileName, contentType, data } = request.data || {};
  const doc = await findByToken(token);
  const app = doc.data();
  requireOpen(app);
  if (!L.DOCUMENT_IDS.has(docType)) {
    throw new HttpsError("invalid-argument", "Unknown document.");
  }
  const current = app.documents?.[docType] || {};
  if (current.status === "approved") {
    throw new HttpsError("failed-precondition",
      "This document is already approved.");
  }
  const type = String(contentType || "").toLowerCase();
  if (!L.ALLOWED_TYPES.has(type)) {
    throw new HttpsError("invalid-argument",
      "Please upload a photo (JPG, PNG, HEIC) or a PDF.");
  }
  const bytes = Buffer.from(String(data || ""), "base64");
  if (bytes.length === 0) {
    throw new HttpsError("invalid-argument", "The file is empty.");
  }
  if (bytes.length > L.MAX_UPLOAD_BYTES) {
    throw new HttpsError("invalid-argument",
      "The file is too large (max 10 MB). Try a smaller photo.");
  }

  const safeName = L.safeFileName(fileName);
  const storagePath = `applications/${doc.id}/${docType}/${Date.now()}_${safeName}`;
  await bucket().file(storagePath).save(bytes, {
    contentType: type,
    resumable: false,
    metadata: { cacheControl: "private, no-store" },
  });

  const entry = {
    status: "uploaded",
    fileName: safeName,
    storagePath,
    contentType: type,
    size: bytes.length,
    uploadedAt: now(),
    comment: "",
    history: current.storagePath
      ? [...(current.history || []), {
          fileName: current.fileName || "",
          storagePath: current.storagePath,
          status: current.status || "",
          comment: current.comment || "",
          uploadedAt: current.uploadedAt || null,
          replacedAt: now(),
        }]
      : current.history || [],
  };
  const update = {
    [`documents.${docType}`]: entry,
    lastApplicantActivityAt: now(),
    updatedAt: now(),
  };
  if (app.status === "invited") update.status = "in_progress";
  await doc.ref.update(update);
  return applicantView({
    ...app,
    status: update.status || app.status,
    documents: { ...app.documents, [docType]: entry },
  });
});

exports.applicationSubmit = onCall(async (request) => {
  const doc = await findByToken(request.data?.token);
  const app = doc.data();
  requireOpen(app);
  const problems = L.submissionProblems(app);
  if (problems.length > 0) {
    throw new HttpsError("failed-precondition",
      "Please complete: " + problems.join(", "));
  }
  const resubmitted = app.status === "needs_changes";
  await doc.ref.update({
    status: "submitted",
    submittedAt: now(),
    lastApplicantActivityAt: now(),
    updatedAt: now(),
    activity: FieldValue.arrayUnion(
      log(app.fullName || "Applicant", resubmitted ? "resubmitted" : "submitted")),
  });
  await notifyAdmins(
    resubmitted ? "Application updated" : "New application",
    `${app.fullName || "An applicant"} ${resubmitted ? "re-submitted" : "submitted"} ` +
      "their documents for review.",
    { applicationId: doc.id });
  return applicantView({ ...app, status: "submitted" });
});

// ── Admin ──

exports.applicationCreate = onCall(emailOptions, async (request) => {
  const me = await requireAdmin(request);
  const fullName = String(request.data?.fullName || "").trim();
  const email = String(request.data?.email || "").trim();
  if (!fullName) throw new HttpsError("invalid-argument", "Name is required.");
  if (email && !L.EMAIL_RE.test(email)) {
    throw new HttpsError("invalid-argument", "That email doesn't look right.");
  }
  const token = L.newToken();
  const app = {
    fullName,
    email,
    status: "invited",
    token,
    tokenHash: L.hashToken(token),
    details: { fullName, email },
    documents: {},
    generalComment: "",
    remindersOff: false,
    reminderCount: 0,
    createdAt: now(),
    invitedAt: now(),
    updatedAt: now(),
    createdBy: me.uid,
    activity: [log(me.name, "created")],
  };
  const ref = await apps().add(app);
  const emailSent = request.data?.sendEmail !== false && email
    ? await inviteEmail(app, token) : false;
  return { id: ref.id, link: linkFor(token), emailSent };
});

exports.applicationList = onCall(async (request) => {
  await requireAdmin(request);
  const snap = await apps().orderBy("createdAt", "desc").limit(500).get();
  return snap.docs.map((d) => {
    const app = d.data();
    const docs = Object.values(app.documents || {});
    return {
      id: d.id,
      fullName: app.fullName || "",
      email: app.email || "",
      phone: app.details?.phone || "",
      status: app.status,
      link: app.token ? linkFor(app.token) : "",
      uploaded: docs.filter((x) => x.storagePath).length,
      approved: docs.filter((x) => x.status === "approved").length,
      needsChanges: docs.filter((x) => x.status === "needs_changes").length,
      total: L.REQUIRED_DOCUMENTS.length,
      createdAt: millis(app.createdAt),
      submittedAt: millis(app.submittedAt),
      lastApplicantActivityAt: millis(app.lastApplicantActivityAt),
      reminderCount: app.reminderCount || 0,
      remindersOff: app.remindersOff === true,
      onboardingStatus: app.onboarding?.status || "not_sent",
      lettersSigned: O.LETTER_IDS.filter((id) => app.onboarding?.letters?.[id]?.signedAt)
        .length,
      loginCreated: Boolean(app.caregiverUid),
    };
  });
});

async function loadForAdmin(id) {
  if (typeof id !== "string" || !id) {
    throw new HttpsError("invalid-argument", "Application id is required.");
  }
  const doc = await apps().doc(id).get();
  if (!doc.exists) throw new HttpsError("not-found", "Application not found.");
  return doc;
}

exports.applicationGetAdmin = onCall(async (request) => {
  await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  return { ...adminView(doc.id, doc.data()), requiredDocuments: L.REQUIRED_DOCUMENTS };
});

/** Edit name / email, or turn reminders on or off. */
exports.applicationUpdate = onCall(async (request) => {
  await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  const update = { updatedAt: now() };
  if (typeof request.data?.fullName === "string" && request.data.fullName.trim()) {
    update.fullName = request.data.fullName.trim();
  }
  if (typeof request.data?.email === "string") {
    const email = request.data.email.trim();
    if (email && !L.EMAIL_RE.test(email)) {
      throw new HttpsError("invalid-argument", "That email doesn't look right.");
    }
    update.email = email;
  }
  if (typeof request.data?.remindersOff === "boolean") {
    update.remindersOff = request.data.remindersOff;
  }
  await doc.ref.update(update);
  return adminView(doc.id, { ...doc.data(), ...update });
});

/** Marks one document approved or needing changes (with a comment). */
exports.applicationReviewDocument = onCall(async (request) => {
  const me = await requireAdmin(request);
  const { id, docType, decision } = request.data || {};
  const comment = String(request.data?.comment || "").trim();
  if (!L.DOCUMENT_IDS.has(docType) ||
      !["approved", "needs_changes", "uploaded"].includes(decision)) {
    throw new HttpsError("invalid-argument", "Invalid review.");
  }
  if (decision === "needs_changes" && !comment) {
    throw new HttpsError("invalid-argument",
      "Add a comment so the applicant knows what to fix.");
  }
  const doc = await loadForAdmin(id);
  const app = doc.data();
  const current = app.documents?.[docType];
  if (!current?.storagePath) {
    throw new HttpsError("failed-precondition", "Nothing uploaded yet.");
  }
  const entry = {
    ...current,
    status: decision,
    comment: decision === "needs_changes" ? comment : "",
    reviewedAt: now(),
    reviewedBy: me.name,
  };
  const label = L.REQUIRED_DOCUMENTS.find((d) => d.id === docType).label;
  await doc.ref.update({
    [`documents.${docType}`]: entry,
    updatedAt: now(),
    activity: FieldValue.arrayUnion(log(me.name,
      decision === "uploaded" ? "review_cleared" : decision,
      decision === "needs_changes" ? `${label}: ${comment}` : label)),
  });
  return adminView(doc.id, {
    ...app,
    documents: { ...app.documents, [docType]: entry },
  });
});

/**
 * accept / reject / request_changes. Requesting changes sends the applicant
 * one email listing every comment, and re-opens their link.
 */
exports.applicationDecide = onCall(emailOptions, async (request) => {
  const me = await requireAdmin(request);
  const { id, decision } = request.data || {};
  const comment = String(request.data?.comment || "").trim();
  const doc = await loadForAdmin(id);
  const app = doc.data();

  if (decision === "request_changes") {
    const flagged = L.REQUIRED_DOCUMENTS.filter((d) =>
      app.documents?.[d.id]?.status === "needs_changes");
    if (flagged.length === 0 && !comment) {
      throw new HttpsError("failed-precondition",
        "Mark a document as needing changes, or add a comment.");
    }
    await doc.ref.update({
      status: "needs_changes",
      generalComment: comment,
      updatedAt: now(),
      activity: FieldValue.arrayUnion(
        log(me.name, "changes_requested", comment)),
    });
    const lines = [
      `Hi ${firstName(app)},`,
      "We reviewed your application. Please fix the following and submit again:",
    ];
    if (comment) lines.push(L.escapeHtml(comment));
    for (const d of flagged) {
      lines.push(`<b>${L.escapeHtml(d.label)}:</b> ` +
        L.escapeHtml(app.documents[d.id].comment));
    }
    const emailSent = app.token
      ? await sendEmail(app.email, "Mega Homecare – changes needed on your application",
        lines, linkFor(app.token))
      : false;
    // A delivered email counts as this round's reminder.
    if (emailSent) await doc.ref.update({ lastReminderAt: now() });
    const updated = (await doc.ref.get()).data();
    return { ...adminView(doc.id, updated), emailSent };
  }

  if (decision === "accept") {
    const notApproved = L.REQUIRED_DOCUMENTS.filter((d) =>
      app.documents?.[d.id]?.status !== "approved");
    if (notApproved.length > 0) {
      throw new HttpsError("failed-precondition",
        "Approve every document first. Not approved yet: " +
        notApproved.map((d) => d.label).join(", "));
    }
  } else if (decision !== "reject" && decision !== "reopen") {
    throw new HttpsError("invalid-argument", "Invalid decision.");
  }

  const status = { accept: "accepted", reject: "rejected", reopen: "submitted" }[decision];
  await doc.ref.update({
    status,
    decidedAt: decision === "reopen" ? null : now(),
    decidedBy: me.uid,
    updatedAt: now(),
    activity: FieldValue.arrayUnion(log(me.name,
      decision === "reopen" ? "reopened" : status, comment)),
  });
  return adminView(doc.id, (await doc.ref.get()).data());
});

/** New link (the old one stops working) and, optionally, a fresh invite email. */
exports.applicationRegenerateLink = onCall(emailOptions, async (request) => {
  const me = await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  const app = doc.data();
  const token = L.newToken();
  const update = {
    token,
    tokenHash: L.hashToken(token),
    invitedAt: now(),
    lastReminderAt: null,
    reminderCount: 0,
    updatedAt: now(),
    activity: FieldValue.arrayUnion(log(me.name, "new_link")),
  };
  await doc.ref.update(update);
  const emailSent = request.data?.sendEmail === true && app.email
    ? await inviteEmail(app, token) : false;
  return { link: linkFor(token), emailSent };
});

/** Re-sends the invite / reminder email right away. */
exports.applicationSendEmail = onCall(emailOptions, async (request) => {
  await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  const app = doc.data();
  if (!app.email) {
    throw new HttpsError("failed-precondition", "This applicant has no email.");
  }
  if (!app.token) throw new HttpsError("failed-precondition", "No link yet.");
  const emailSent = L.reminderPhase(app) === "onboarding"
    ? await lettersEmail(app, true)
    : app.status === "invited"
    ? await inviteEmail(app, app.token)
    : await sendEmail(app.email, "Mega Homecare – reminder about your application",
      [`Hi ${firstName(app)},`, missingList(app)], linkFor(app.token));
  if (emailSent) await doc.ref.update({ lastReminderAt: now() });
  return { emailSent };
});

exports.applicationDelete = onCall(async (request) => {
  await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  await bucket().deleteFiles({ prefix: `applications/${doc.id}/` })
    .catch((e) => logger.error("Deleting applicant files failed", e));
  await doc.ref.delete();
  return { deleted: true };
});

// ── Documents vault (separate password for opening uploaded files) ──

const MAX_VAULT_FAILURES = 8;
const VAULT_LOCK_MS = 15 * 60 * 1000;

exports.vaultStatus = onCall(async (request) => {
  await requireAdmin(request);
  const vault = (await vaultRef().get()).data();
  return { isSet: Boolean(vault?.hash) };
});

/**
 * First-time set, change (with the current vault password) or reset (when
 * the admin signed in again in the last 5 minutes — the "forgot vault
 * password" path). Returns an unlocked vault token.
 */
exports.vaultSetPassword = onCall(async (request) => {
  const me = await requireAdmin(request);
  const { currentPassword, newPassword } = request.data || {};
  if (typeof newPassword !== "string" || newPassword.length < 6) {
    throw new HttpsError("invalid-argument",
      "The documents password must be at least 6 characters.");
  }
  const vault = (await vaultRef().get()).data();
  if (vault?.hash) {
    const authAgeMs = Date.now() - (request.auth.token.auth_time || 0) * 1000;
    const recentlySignedIn = authAgeMs < 5 * 60 * 1000;
    const knowsCurrent = typeof currentPassword === "string" && currentPassword &&
      L.verifyPassword(currentPassword, vault.salt, vault.hash);
    if (!knowsCurrent && !recentlySignedIn) {
      throw new HttpsError("permission-denied",
        "The current documents password is incorrect.");
    }
  }
  const { salt, hash } = L.hashPassword(newPassword);
  // A new secret also signs out every open vault session.
  const secret = crypto.randomBytes(32).toString("hex");
  await vaultRef().set({
    salt, hash, secret,
    failures: {},
    updatedAt: now(),
    updatedBy: me.uid,
  });
  return { vaultToken: L.signVaultToken(me.uid, secret) };
});

exports.vaultUnlock = onCall(async (request) => {
  const me = await requireAdmin(request);
  const ref = vaultRef();
  const vault = (await ref.get()).data();
  if (!vault?.hash) {
    throw new HttpsError("failed-precondition", "Set a documents password first.");
  }
  const failure = vault.failures?.[me.uid] || { count: 0, at: 0 };
  if (failure.count >= MAX_VAULT_FAILURES && Date.now() - failure.at < VAULT_LOCK_MS) {
    throw new HttpsError("resource-exhausted",
      "Too many wrong attempts. Try again in 15 minutes.");
  }
  if (!L.verifyPassword(String(request.data?.password || ""), vault.salt, vault.hash)) {
    await ref.update({
      [`failures.${me.uid}`]: { count: failure.count + 1, at: Date.now() },
    });
    throw new HttpsError("permission-denied", "Wrong documents password.");
  }
  if (failure.count) {
    await ref.update({ [`failures.${me.uid}`]: FieldValue.delete() });
  }
  return { vaultToken: L.signVaultToken(me.uid, vault.secret) };
});

/** One uploaded file (current or from history), as base64. */
exports.applicationGetDocument = onCall(uploadOptions, async (request) => {
  const me = await requireAdmin(request);
  const vault = (await vaultRef().get()).data();
  if (!vault?.secret ||
      !L.verifyVaultToken(request.data?.vaultToken, me.uid, vault.secret)) {
    throw new HttpsError("permission-denied", "vault-locked");
  }
  const { id, docType } = request.data || {};
  const doc = await loadForAdmin(id);
  const current = doc.data().documents?.[docType];
  if (!current) throw new HttpsError("not-found", "No such document.");
  const path = request.data?.storagePath || current.storagePath;
  const entry = path === current.storagePath
    ? current : (current.history || []).find((h) => h.storagePath === path);
  if (!entry || !path.startsWith(`applications/${doc.id}/`)) {
    throw new HttpsError("not-found", "No such file.");
  }
  const [bytes] = await bucket().file(path).download();
  return {
    fileName: entry.fileName || "document",
    contentType: entry.contentType || current.contentType || "application/octet-stream",
    data: bytes.toString("base64"),
  };
});

// ── Onboarding letters (stage 2) ──

/** The five letters with Becky's fields filled in, before sending. */
exports.onboardingPreview = onCall(async (request) => {
  await requireAdmin(request);
  const { fields, missing } = O.normalizeFields(request.data?.fields);
  return {
    missing,
    letters: O.buildLetters(fields).map((l) => ({
      id: l.id, title: l.title, heading: l.heading, blocks: l.blocks,
    })),
  };
});

/**
 * Saves Becky's fields and opens the letters on the applicant's link. Can be
 * repeated to fix a detail until the first letter is signed.
 */
exports.onboardingSend = onCall(emailOptions, async (request) => {
  const me = await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  const app = doc.data();
  if (app.status !== "accepted") {
    throw new HttpsError("failed-precondition", "Accept the application first.");
  }
  const signed = O.LETTER_IDS.filter((id) => app.onboarding?.letters?.[id]?.signedAt);
  if (signed.length > 0) {
    throw new HttpsError("failed-precondition",
      "The caregiver has already started signing, so the documents can't be changed.");
  }
  const { fields, missing } = O.normalizeFields(request.data?.fields);
  if (missing.length > 0) {
    throw new HttpsError("invalid-argument", "Please fill in: " + missing.join(", "));
  }
  const resend = app.onboarding?.status === "sent";
  const onboarding = {
    status: "sent",
    fields,
    letters: {},
    signaturePath: null,
    sentAt: now(),
    sentBy: me.uid,
  };
  await doc.ref.update({
    onboarding,
    lastReminderAt: null,
    reminderCount: 0,
    updatedAt: now(),
    activity: FieldValue.arrayUnion(log(me.name, resend ? "letters_updated" : "letters_sent")),
  });
  const updated = { ...app, onboarding };
  const emailSent = request.data?.sendEmail !== false && app.email && app.token
    ? await lettersEmail(updated, false) : false;
  if (emailSent) await doc.ref.update({ lastReminderAt: now() });
  return { ...adminView(doc.id, (await doc.ref.get()).data()), emailSent };
});

const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47]);

/** The applicant signs one letter (drawing their signature the first time). */
/** File name for a caregiver's copy, e.g. "Offer_Letter_Grace_Obi.pdf". */
function signedFileName(letter, fullName) {
  return `${letter.title}_${fullName || "caregiver"}`.replace(/[^A-Za-z0-9]+/g, "_") + ".pdf";
}

/** Emails the caregiver a copy of every signed document; false on failure. */
async function emailSignedCopies(app) {
  const ob = app.onboarding;
  if (!app.email) return false;
  const letters = O.buildLetters(ob.fields);
  const attachments = [];
  for (const l of letters) {
    const path = ob.letters?.[l.id]?.pdfPath;
    if (!path) continue;
    const [content] = await bucket().file(path).download();
    attachments.push({
      filename: signedFileName(l, ob.fields.fullName),
      content,
      contentType: "application/pdf",
    });
  }
  return sendEmail(app.email, "Your signed Mega Homecare onboarding documents", [
    `Hi ${firstName(app)},`,
    "Thank you for signing your onboarding documents. A copy of each signed " +
      "document is attached for your records. You can also download them " +
      "anytime from your link.",
    "Mega Homecare will send you your app login soon.",
  ], linkFor(app.token), "Open my documents", attachments);
}

exports.onboardingSign = onCall({ ...uploadOptions, ...emailOptions }, async (request) => {
  const { token, letterId, signature } = request.data || {};
  const doc = await findByToken(token);
  const app = doc.data();
  const ob = app.onboarding;
  if (app.status !== "accepted" || ob?.status !== "sent") {
    throw new HttpsError("failed-precondition",
      ob?.status === "completed"
        ? "All your documents are already signed."
        : "Your documents are not ready to sign yet.");
  }
  if (!O.LETTER_IDS.includes(letterId)) {
    throw new HttpsError("invalid-argument", "Unknown document.");
  }
  if (ob.letters?.[letterId]?.signedAt) {
    throw new HttpsError("failed-precondition", "You already signed this document.");
  }
  if (request.data?.agree !== true) {
    throw new HttpsError("invalid-argument", "Please confirm that you have read the document.");
  }

  let signaturePath = ob.signaturePath;
  let signatureBytes;
  if (signature) {
    signatureBytes = Buffer.from(String(signature), "base64");
    if (signatureBytes.length < 100 || signatureBytes.length > 500 * 1024 ||
        !signatureBytes.subarray(0, 4).equals(PNG_MAGIC)) {
      throw new HttpsError("invalid-argument", "Please draw your signature again.");
    }
    signaturePath = `applications/${doc.id}/onboarding/signature_${Date.now()}.png`;
    await bucket().file(signaturePath).save(signatureBytes,
      { contentType: "image/png", resumable: false });
  } else if (signaturePath) {
    [signatureBytes] = await bucket().file(signaturePath).download();
  } else {
    throw new HttpsError("invalid-argument", "Please draw your signature.");
  }

  const headers = request.rawRequest?.headers || {};
  const ip = String(headers["x-forwarded-for"] || request.rawRequest?.ip || "")
    .split(",")[0].trim();
  const userAgent = String(headers["user-agent"] || "").slice(0, 300);
  const signedAt = new Date();
  const letter = O.buildLetters(ob.fields).find((l) => l.id === letterId);
  const pdf = await O.renderLetterPdf(letter, {
    name: ob.fields.fullName,
    signature: signatureBytes,
    signedAt,
    audit: ip ? `IP ${ip}` : "",
  });
  const pdfPath = `applications/${doc.id}/onboarding/${letterId}_${signedAt.getTime()}.pdf`;
  await bucket().file(pdfPath).save(pdf,
    { contentType: "application/pdf", resumable: false });

  await doc.ref.update({
    [`onboarding.letters.${letterId}`]: {
      signedAt: Timestamp.fromDate(signedAt), pdfPath, ip, userAgent,
    },
    "onboarding.signaturePath": signaturePath,
    lastApplicantActivityAt: now(),
    updatedAt: now(),
  });

  // Last letter: mark onboarding complete and tell the admins.
  const fresh = (await doc.ref.get()).data();
  const allSigned = O.LETTER_IDS.every((id) => fresh.onboarding?.letters?.[id]?.signedAt);
  if (allSigned && fresh.onboarding.status === "sent") {
    await doc.ref.update({
      "onboarding.status": "completed",
      "onboarding.completedAt": now(),
      activity: FieldValue.arrayUnion(log(ob.fields.fullName, "letters_signed")),
    });
    await notifyAdmins("Onboarding documents signed",
      `${ob.fields.fullName} signed all 5 onboarding documents. You can now create their login.`,
      { applicationId: doc.id });
    // Their own copies, for their records. An email failure doesn't undo
    // the signing; they can still download each document from their link.
    const emailed = await emailSignedCopies(fresh).catch((e) => {
      logger.error("Emailing signed copies failed", e);
      return false;
    });
    if (emailed) await doc.ref.update({ "onboarding.copiesEmailedAt": now() });
  }
  return applicantView((await doc.ref.get()).data());
});

/** The applicant downloads their own copy of one signed document. */
exports.onboardingDownload = onCall(uploadOptions, async (request) => {
  const doc = await findByToken(request.data?.token);
  const app = doc.data();
  const ob = app.onboarding;
  const letter = ob?.fields &&
    O.buildLetters(ob.fields).find((l) => l.id === request.data?.letterId);
  const entry = letter && ob.letters?.[letter.id];
  if (app.status !== "accepted" || !entry?.pdfPath) {
    throw new HttpsError("not-found", "This document isn't signed yet.");
  }
  const [bytes] = await bucket().file(entry.pdfPath).download();
  return {
    fileName: signedFileName(letter, ob.fields.fullName),
    contentType: "application/pdf",
    data: bytes.toString("base64"),
  };
});

/** One signed letter as a PDF (behind the documents password). */
exports.onboardingGetLetter = onCall(uploadOptions, async (request) => {
  const me = await requireAdmin(request);
  const vault = (await vaultRef().get()).data();
  if (!vault?.secret ||
      !L.verifyVaultToken(request.data?.vaultToken, me.uid, vault.secret)) {
    throw new HttpsError("permission-denied", "vault-locked");
  }
  const doc = await loadForAdmin(request.data?.id);
  const ob = doc.data().onboarding;
  const entry = ob?.letters?.[request.data?.letterId];
  if (!entry?.pdfPath) throw new HttpsError("not-found", "This document isn't signed yet.");
  const [bytes] = await bucket().file(entry.pdfPath).download();
  const name = (ob.fields.fullName || "caregiver").replace(/[^A-Za-z0-9]+/g, "_");
  return {
    fileName: `${request.data.letterId}_${name}.pdf`,
    contentType: "application/pdf",
    data: bytes.toString("base64"),
  };
});

const USERNAME_RE = /^[a-z0-9._-]{3,30}$/;

/** Creates the caregiver's app login once every letter is signed. */
exports.onboardingCreateLogin = onCall(async (request) => {
  const me = await requireAdmin(request);
  const doc = await loadForAdmin(request.data?.id);
  const app = doc.data();
  if (app.onboarding?.status !== "completed") {
    throw new HttpsError("failed-precondition",
      "The caregiver has to sign all 5 documents first.");
  }
  if (app.caregiverUid) {
    throw new HttpsError("already-exists",
      `A login was already created (@${app.caregiverUsername}).`);
  }
  const username = String(request.data?.username || "").trim().toLowerCase();
  const password = String(request.data?.password || "");
  if (!USERNAME_RE.test(username)) {
    throw new HttpsError("invalid-argument",
      "Username: 3–30 characters, letters, numbers, dot, dash or underscore.");
  }
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }
  const taken = await db().collection("users").where("username", "==", username)
    .limit(1).get();
  if (!taken.empty) {
    throw new HttpsError("already-exists", `Username "${username}" is already taken.`);
  }

  const d = app.details || {};
  const fullName = app.onboarding.fields.fullName || app.fullName;
  let user;
  try {
    user = await admin.auth().createUser({
      email: `${username}@megahomecare.app`,
      password,
      displayName: fullName,
    });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", `Username "${username}" is already taken.`);
    }
    throw new HttpsError("internal", e.message);
  }
  const em = d.emergency || {};
  await db().collection("users").doc(user.uid).set({
    username,
    fullName,
    role: "caregiver",
    phone: d.phone || "",
    address: "",
    emergencyContact: [em.name, em.relation && `(${em.relation})`, em.phone]
      .filter(Boolean).join(" "),
    photoUrl: "",
    isActive: true,
    createdAt: Timestamp.now(),
    email: d.email || app.email || "",
    applicationId: doc.id,
  });
  await doc.ref.update({
    caregiverUid: user.uid,
    caregiverUsername: username,
    updatedAt: now(),
    activity: FieldValue.arrayUnion(log(me.name, "login_created", `@${username}`)),
  });
  return { uid: user.uid, username };
});

// ── Reminders ──

exports.sendApplicationReminders = onSchedule(
  { schedule: "0 8,12,16,20 * * *", timeZone: L.AGENCY_TIME_ZONE,
    secrets: [SMTP_PASSWORD] },
  async () => {
    const snap = await apps()
      .where("status", "in", [...L.OPEN_STATUSES, "accepted"]).get();
    const nowDate = new Date();
    for (const doc of snap.docs) {
      const app = doc.data();
      if (!app.token || !L.shouldRemind(app, nowDate)) continue;
      if (L.reminderPhase(app) === "onboarding") {
        if (await lettersEmail(app, true)) {
          await doc.ref.update({
            lastReminderAt: now(),
            reminderCount: FieldValue.increment(1),
          });
        }
        continue;
      }
      const fixing = app.status === "needs_changes";
      const sent = await sendEmail(app.email,
        fixing
          ? "Reminder: changes needed on your Mega Homecare application"
          : "Reminder: please complete your Mega Homecare application",
        [
          `Hi ${firstName(app)},`,
          fixing
            ? "This is a friendly reminder to fix the items we asked about " +
              "and submit your application again."
            : "This is a friendly reminder to finish your application with " +
              "Mega Homecare.",
          missingList(app),
        ],
        linkFor(app.token));
      if (sent) {
        await doc.ref.update({
          lastReminderAt: now(),
          reminderCount: FieldValue.increment(1),
        });
      }
    }
  },
);
