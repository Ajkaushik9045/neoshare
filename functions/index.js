const {setGlobalOptions} = require("firebase-functions");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

initializeApp();
setGlobalOptions({maxInstances: 10});

/**
 * Fires when a transfer document is updated.
 * Sends an FCM push to the recipient when status → "complete".
 */
exports.notifyRecipientOnTransferComplete = onDocumentUpdated(
    "transfers/{transferId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const transferId = event.params.transferId;

      logger.info(
          `[FCM] Transfer ${transferId}: ` +
            `${before.status} → ${after.status}`,
      );

      if (before.status === after.status) {
        logger.debug(`[FCM] Status unchanged, skipping.`);
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
          body: `${senderCode} sent you ${noun}. ` +
                    "Open NeoShare to download.",
        },
        data: {
          transferId,
          action: "open_receive",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "neoshare_incoming",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
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
