/**
 * Import function triggers from their respective submodules
 */
const {onCall} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// User account deletion function
exports.deleteUserAccount = onCall(async (request) => {
  // Ensure the user is authenticated
  if (!request.auth) {
    throw new Error("You must be logged in to delete your account.");
  }

  const uid = request.auth.uid;

  // Only allow users to delete their own accounts
  if (uid !== request.data.userId) {
    throw new Error("You can only delete your own account.");
  }

  const db = admin.firestore();
  const auth = admin.auth();

  try {
    // Start a batch operation for atomic updates
    const batch = db.batch();

    // 1. Delete saved maps subcollection
    const savedMapsSnapshot = await db
      .collection("users")
      .doc(uid)
      .collection("saved_maps")
      .get();

    savedMapsSnapshot.forEach(doc => {
      batch.delete(doc.ref);
    });

    // 2. Delete route history subcollection
    const routeHistorySnapshot = await db
      .collection("users")
      .doc(uid)
      .collection("route_history")
      .get();

    routeHistorySnapshot.forEach(doc => {
      batch.delete(doc.ref);
    });

    // 3. Delete user document
    batch.delete(db.collection("users").doc(uid));

    // 4. Delete user metrics
    batch.delete(db.collection("user_metrics").doc(uid));

    // Commit all the batch operations
    await batch.commit();

    // 5. Finally, delete the user from Firebase Authentication
    await auth.deleteUser(uid);

    return { success: true, message: "Account deleted successfully" };
  } catch (error) {
    logger.error("Error deleting account:", error);
    throw new Error("Error deleting account: " + error.message);
  }
});

// Scheduled function to aggregate route data
// Using v2 scheduled functions syntax
exports.aggregateRouteData = onSchedule({
  schedule: "every 24 hours",
  timeZone: "America/New_York", // Set your desired timezone
}, async (event) => {
  const db = admin.firestore();

  try {
    // Get all active users
    const usersSnapshot = await db
      .collection("users")
      .where("is_active", "==", true)
      .get();

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;

      // Get routes from the last 24 hours
      const routesSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("route_history")
        .where("created_at", ">", new Date(Date.now() - 86400000))
        .get();

      if (routesSnapshot.empty) continue;

      // Calculate metrics
      let totalDistance = 0;
      let totalDuration = 0;
      const destinations = new Map();

      routesSnapshot.forEach(doc => {
        const data = doc.data();
        totalDistance += (data.distance && data.distance.value) || 0;
        totalDuration += (data.duration && data.duration.value) || 0;

        // Track destinations
        const endPlaceId = data.end_location && data.end_location.place_id;
        if (endPlaceId) {
          const count = destinations.get(endPlaceId) || 0;
          destinations.set(endPlaceId, count + 1);
        }
      });

      // Update user metrics
      await db.collection("user_metrics").doc(userId).update({
        "last_active": admin.firestore.FieldValue.serverTimestamp(),
        "recent_distance": totalDistance / 1000, // Convert to km
        "recent_duration": totalDuration / 60, // Convert to minutes
        "favorite_destinations": Array.from(destinations.entries())
          .sort((a, b) => b[1] - a[1])
          .slice(0, 5)
          .map(([placeId, count]) => ({place_id: placeId, count})),
      });
    }

    logger.info("Route data aggregation completed successfully");
    return null;
  } catch (error) {
    logger.error("Error aggregating route data:", error);
    return null;
  }
});