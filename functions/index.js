const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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
