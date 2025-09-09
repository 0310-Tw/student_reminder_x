const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require('firebase-admin');

admin.initializeApp();

// Simple test function
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase!");
});

// Enhanced notification sending function for testing
exports.sendFCMNotification = onRequest(async (request, response) => {
  try {
    const { token, title, body, type } = request.body;
    
    if (!token || !title || !body) {
      response.status(400).send({ error: 'Missing required fields: token, title, body' });
      return;
    }

    // Construct the FCM payload with enhanced foreground support
    const payload = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: type || 'admin_action',
        timestamp: Date.now().toString(),
      },
      // Enhanced options for foreground delivery
      android: {
        priority: 'high',
        notification: {
          channelId: 'admin_actions',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            badge: 1,
            'content-available': 1,
          },
        },
        headers: {
          'apns-priority': '10',
        },
      },
    };

    // Send the message
    const messageId = await admin.messaging().send(payload);
    console.log('Successfully sent message:', messageId);

    response.send({ success: true, messageId: messageId });
  } catch (error) {
    console.error('Error sending FCM message:', error);
    response.status(500).send({ error: error.message });
  }
});
