const {setGlobalOptions} = require("firebase-functions");
const {onDocumentUpdated, onDocumentCreated} =
  require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

initializeApp();
setGlobalOptions({maxInstances: 10});

// Max transfers a single sender can create within a rolling 1-hour window.
const RATE_LIMIT_PER_HOUR = 10;

/**
 * Rate-limits transfer creation per sender.
 *
 * Fires on every new transfer document. Counts how many transfers the same
 * senderCode created in the last hour. If the count exceeds the limit the
 * new document is deleted immediately, preventing the upload from starting.
 */
exports.enforceTransferRateLimit = onDocumentCreated(
    "transfers/{transferId}",
    async (event) => {
      const data = event.data.data();
      const senderCode = data.senderCode;
      const transferId = event.params.transferId;

      if (!senderCode) {
        logger.warn(
            `[RateLimit] Transfer ${transferId} has no senderCode, skip.`,
        );
        return null;
      }

      const db = getFirestore();
      const oneHourAgo = Timestamp.fromDate(
          new Date(Date.now() - 60 * 60 * 1000),
      );

      const snap = await db
          .collection("transfers")
          .where("senderCode", "==", senderCode)
          .where("createdAt", ">=", oneHourAgo)
          .count()
          .get();

      const count = snap.data().count;

      logger.info(
          `[RateLimit] sender=${senderCode} ` +
      `count=${count} limit=${RATE_LIMIT_PER_HOUR}`,
      );

      if (count > RATE_LIMIT_PER_HOUR) {
        logger.warn(
            `[RateLimit] sender=${senderCode} exceeded limit. ` +
        `Deleting transfer ${transferId}.`,
        );
        await event.data.ref.delete();
      }

      return null;
    },
);

/**
 * Fires when a transfer document is updated.
 * Sends FCM push to recipient when status transitions to "complete".
 */
exports.notifyRecipientOnTransferComplete = onDocumentUpdated(
    "transfers/{transferId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const transferId = event.params.transferId;

      logger.info(
          `[FCM] Transfer ${transferId}: ${before.status} → ${after.status}`,
      );

      if (before.status === after.status) {
        logger.debug("[FCM] Status unchanged, skipping.");
        return null;
      }
      if (after.status !== "complete") {
        logger.debug(`[FCM] Status "${after.status}" != complete, skip.`);
        return null;
      }

      const recipientCode = after.recipientCode;
      const senderCode = after.senderCode || "Someone";
      const fileCount = (after.files || []).length;
      const noun = fileCount === 1 ? "1 file" : `${fileCount} files`;

      logger.info(
          `[FCM] Complete — sender=${senderCode} ` +
      `recipient=${recipientCode} files=${fileCount}`,
      );

      if (!recipientCode) {
        logger.warn(`[FCM] ${transferId} missing recipientCode, abort.`);
        return null;
      }

      const db = getFirestore();
      logger.info(`[FCM] Fetching user doc for code=${recipientCode}`);

      const userDoc = await db
          .collection("users")
          .doc(recipientCode)
          .get();

      if (!userDoc.exists) {
        logger.warn(`[FCM] No user doc for code=${recipientCode}, abort.`);
        return null;
      }

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) {
        logger.warn(`[FCM] No FCM token for ${recipientCode}, abort.`);
        return null;
      }

      logger.info(`[FCM] Sending push to ${recipientCode}`);

      const message = {
        token: fcmToken,
        notification: {
          title: "You have a file waiting",
          body: `${senderCode} sent you ${noun}. Open NeoShare to download.`,
        },
        data: {
          transferId,
          action: "open_receive",
          deepLink: "neoshare://receive",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      try {
        const msgId = await getMessaging().send(message);
        logger.info(`[FCM] Sent to ${recipientCode}. id=${msgId}`);
      } catch (err) {
        logger.error(`[FCM] Send failed for ${recipientCode}:`, err);
      }

      return null;
    },
);

const {onSchedule} = require("firebase-functions/v2/scheduler");

/**
 * Runs every 6 hours. Finds all transfers where expiresAt is in the past
 * and status is not already "expired", marks them expired, and deletes
 * their Firebase Storage files to free up space.
 */
exports.expireStaleTransfers = onSchedule("every 6 hours", async () => {
  const db = getFirestore();
  const now = Timestamp.now();

  const stale = await db
      .collection("transfers")
      .where("expiresAt", "<=", now)
      .where("status", "!=", "expired")
      .get();

  if (stale.empty) {
    logger.info("[Expire] No stale transfers found.");
    return;
  }

  logger.info(`[Expire] Found ${stale.size} stale transfer(s) to expire.`);

  const {getStorage} = require("firebase-admin/storage");
  const bucket = getStorage().bucket();

  const batch = db.batch();

  for (const doc of stale.docs) {
    const transferId = doc.id;

    // Mark as expired in Firestore
    batch.update(doc.ref, {status: "expired"});

    // Delete all Storage files for this transfer
    const storagePath = `transfers/${transferId}`;
    try {
      await bucket.deleteFiles({prefix: storagePath});
      logger.info(`[Expire] Deleted storage files for ${transferId}`);
    } catch (err) {
      logger.warn(
          `[Expire] Could not delete storage for ${transferId}:`,
          err.message,
      );
    }
  }

  await batch.commit();
  logger.info(`[Expire] Marked ${stale.size} transfer(s) as expired.`);
});
