const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let initialized = false;

function initFirebaseAdmin() {
  if (initialized) return;

  try {
    let serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || path.join(__dirname, '../../firebase-service-account.json');

    if (!fs.existsSync(serviceAccountPath)) {
      const backendDir = path.join(__dirname, '../../');
      const files = fs.readdirSync(backendDir);
      const match = files.find(f => f.includes('firebase-adminsdk') && f.endsWith('.json'));
      if (match) {
        serviceAccountPath = path.join(backendDir, match);
      }
    }

    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      initialized = true;
      console.log(`Firebase Admin SDK initialized successfully with ${path.basename(serviceAccountPath)}.`);
    } else if (process.env.FIREBASE_CONFIG) {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_CONFIG))
      });
      initialized = true;
      console.log('Firebase Admin SDK initialized successfully with FIREBASE_CONFIG env var.');
    } else {
      console.warn('[Firebase] Warning: No service account credentials found. FCM Push Notifications will be disabled until firebase-service-account.json is added.');
    }
  } catch (error) {
    console.error('[Firebase] Failed to initialize Firebase Admin SDK:', error.message);
  }
}

async function sendPushNotification(tokens, title, body, data = {}) {
  initFirebaseAdmin();

  if (!initialized) {
    console.warn('[Firebase] Notification skipped: Firebase Admin SDK not initialized.');
    return { success: false, reason: 'Firebase not initialized' };
  }

  try {
    const tokenList = Array.isArray(tokens) ? tokens : [tokens];
    if (tokenList.length === 0) return { success: false, reason: 'No tokens provided' };

    const message = {
      notification: { title, body },
      data: data,
      tokens: tokenList
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`[Firebase] Push notification sent to ${response.successCount} devices.`);
    return { success: true, response };
  } catch (error) {
    console.error('[Firebase] Error sending push notification:', error);
    return { success: false, error };
  }
}

module.exports = {
  initFirebaseAdmin,
  sendPushNotification
};
