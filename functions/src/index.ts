import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

interface PushNotificationData {
  title: string;
  body: string;
  token?: string;
  topic?: string;
}

// Send notification to a single device
export const sendPushNotification = functions.https.onRequest(async (req, res) => {
  // Enable CORS for web testing
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { title, body, token } = req.body as PushNotificationData;

  if (!token || !title || !body) {
    res.status(400).send({ success: false, error: "Missing title, body, or token" });
    return;
  }

  const message = {
    notification: { title, body },
    token,
  };

  console.log("sendPushNotification called with:", { title, body, token });

  try {
    const response = await admin.messaging().send(message);
    res.send({ success: true, response });
  } catch (error: any) {
    res.status(500).send({
      success: false,
      error: "Failed to send notification",
      details: error.message || error,
    });
  }
});

// Send notification to a topic
export const sendTopicNotification = functions.https.onRequest(async (req, res) => {
  // Enable CORS for web testing
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const { title, body, topic } = req.body as PushNotificationData;

  if (!topic || !title || !body) {
    res.status(400).send({ success: false, error: "Missing title, body, or topic" });
    return;
  }

  const message = {
    notification: { title, body },
    topic,
  };

  console.log("sendTopicNotification called with:", { title, body, topic });

  try {
    const response = await admin.messaging().send(message);
    res.send({ success: true, response });
  } catch (error: any) {
    res.status(500).send({
      success: false,
      error: "Failed to send topic notification",
      details: error.message || error,
    });
  }
});

// Scheduled functions for daily reminders
export const sendMorningReminder = functions.pubsub.schedule('0 8 * * 1-5')
  .timeZone('America/New_York') // Adjust to your timezone
  .onRun(async (context) => {
    const message = {
      notification: {
        title: 'Time to Check In!',
        body: "Don't forget to mark your attendance for today.",
      },
      topic: 'morning_reminders',
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Morning reminder sent:', response);
    } catch (error) {
      console.error('Error sending morning reminder:', error);
    }
  });

export const sendEveningReminder = functions.pubsub.schedule('55 15 * * 1-5')
  .timeZone('America/New_York') // Adjust to your timezone
  .onRun(async (context) => {
    const message = {
      notification: {
        title: 'Time to Check Out!',
        body: "Don't forget to mark your departure for today.",
      },
      topic: 'evening_reminders',
    };

    try {
      const response = await admin.messaging().send(message);
      console.log('Evening reminder sent:', response);
    } catch (error) {
      console.error('Error sending evening reminder:', error);
    }
  });
