const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  AGENCY_TIME_ZONE,
  startOfZonedDay,
  findMissedShifts,
} = require("./missed_clockins");

admin.initializeApp();

exports.checkMissedClockIns = onSchedule(
  { schedule: "every 5 minutes", timeZone: AGENCY_TIME_ZONE },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const [assignmentSnap, clockSnap] = await Promise.all([
      db.collection("assignments").where("isActive", "==", true).get(),
      db.collection("clock_records")
        .where("clockInTime", ">=",
          admin.firestore.Timestamp.fromDate(
            startOfZonedDay(now, AGENCY_TIME_ZONE)))
        .get(),
    ]);

    const clockedIn = new Set(
      clockSnap.docs.map((d) => d.data().assignmentId).filter(Boolean));
    const missed = findMissedShifts({
      now,
      assignments: assignmentSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      clockedInAssignmentIds: clockedIn,
    });
    if (missed.length === 0) return;

    const adminSnap = await db.collection("users")
      .where("role", "==", "admin").get();
    const adminTokens = adminSnap.docs
      .map((d) => d.data())
      .filter((u) => u.isActive !== false && typeof u.fcmToken === "string" &&
        u.fcmToken)
      .map((u) => u.fcmToken);

    for (const { assignment: a, dateKey, minutesLate } of missed) {
      const [client, caregiver] = await Promise.all([
        db.collection("users").doc(a.clientId).get(),
        db.collection("users").doc(a.caregiverId).get(),
      ]);
      if (client.data()?.isActive === false ||
          caregiver.data()?.isActive === false) continue;

      // create() fails if the doc exists, so each shift alerts only once.
      try {
        await db.collection("missed_clockins").doc(`${a.id}_${dateKey}`)
          .create({
            assignmentId: a.id,
            caregiverId: a.caregiverId,
            caregiverName: a.caregiverName || "",
            clientId: a.clientId,
            clientName: a.clientName || "",
            shiftDate: dateKey,
            shiftStartTime: a.shiftStartTime,
            minutesLateWhenDetected: minutesLate,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (e) {
        if (e.code === 6) continue; // ALREADY_EXISTS
        throw e;
      }

      if (adminTokens.length === 0) continue;
      await admin.messaging().sendEachForMulticast({
        tokens: adminTokens,
        notification: {
          title: "Missed clock-in",
          body: `${a.caregiverName || "A caregiver"} hasn't clocked in for ` +
            `${a.clientName || "a client"} (shift started ${a.shiftStartTime}).`,
        },
        data: { type: "missed_clockin", assignmentId: a.id, chatId: "",
          callId: "" },
        android: {
          priority: "high",
          notification: { channelId: "messages_channel", sound: "default" },
        },
        apns: { payload: { aps: { sound: "default" } } },
      });
    }
  },
);

exports.resetUserPassword = onCall(async (request) => {
  // Only allow authenticated admin users
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const callerUid = request.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection("users")
    .doc(callerUid)
    .get();

  if (!callerDoc.exists || callerDoc.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Only admins can reset passwords.");
  }

  const { uid, newPassword } = request.data;

  if (!uid || !newPassword) {
    throw new HttpsError("invalid-argument", "uid and newPassword are required.");
  }

  if (newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Password must be at least 6 characters.");
  }

  try {
    await admin.auth().updateUser(uid, { password: newPassword });

    // Clear any pending reset requests for this user
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (userDoc.exists) {
      const username = userDoc.data().username;
      if (username) {
        const requests = await admin
          .firestore()
          .collection("password_reset_requests")
          .where("username", "==", username)
          .where("status", "==", "pending")
          .get();
        const batch = admin.firestore().batch();
        requests.docs.forEach((doc) => {
          batch.update(doc.ref, { status: "completed" });
        });
        await batch.commit();
      }
    }

    return { success: true };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

exports.sendPushNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const { receiverId, type, chatId, callId } = request.data || {};
  if (typeof receiverId !== "string" || !receiverId ||
      (type !== "message" && type !== "call")) {
    throw new HttpsError("invalid-argument", "Invalid notification request.");
  }

  const senderId = request.auth.uid;
  let title;
  let body;
  let data;

  if (type === "message") {
    if (typeof chatId !== "string" || !chatId) {
      throw new HttpsError("invalid-argument", "chatId is required.");
    }
    const chat = await admin.firestore().collection("chats").doc(chatId).get();
    const details = chat.data();
    if (!details || !Array.isArray(details.participants) ||
        !details.participants.includes(senderId) ||
        !details.participants.includes(receiverId) ||
        senderId === receiverId || details.lastMessageSenderId !== senderId) {
      throw new HttpsError("permission-denied", "Not allowed to notify this chat.");
    }
    title = details.participantNames?.[senderId] || "New message";
    body = details.lastMessageType === "image"
      ? "Sent a photo" : details.lastMessage || "New message";
    data = { type, chatId, callId: "" };
  } else {
    if (typeof callId !== "string" || !callId) {
      throw new HttpsError("invalid-argument", "callId is required.");
    }
    const call = await admin.firestore().collection("calls").doc(callId).get();
    const details = call.data();
    if (!details || details.callerId !== senderId ||
        details.receiverId !== receiverId || details.status !== "ringing") {
      throw new HttpsError("permission-denied", "Not allowed to notify this call.");
    }
    title = details.callerName || "Incoming call";
    body = details.type === "video"
      ? "Incoming Video Call" : "Incoming Audio Call";
    data = { type, callId, chatId: "" };
  }

  const user = await admin.firestore().collection("users").doc(receiverId).get();
  const token = user.data()?.fcmToken;
  if (typeof token !== "string" || !token) return { sent: false };

  await admin.messaging().send({
    token,
    notification: { title: String(title), body: String(body) },
    data,
    android: {
      priority: "high",
      notification: {
        channelId: type === "call" ? "calls_channel" : "messages_channel",
        sound: "default",
      },
    },
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
  });
  return { sent: true };
});
