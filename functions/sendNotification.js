// file: functions/sendNotification.js
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Send push notification to specific device token
 */
exports.sendNotificationToToken = async (token, title, body, data = {}) => {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    token: token,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    console.log('Error sending message:', error);
    throw error;
  }
};

/**
 * Send notification to topic (e.g., all students)
 */
exports.sendNotificationToTopic = async (topic, title, body, data = {}) => {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    topic: topic,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message to topic:', response);
    return response;
  } catch (error) {
    console.log('Error sending message to topic:', error);
    throw error;
  }
};

/**
 * Cloud Function to send daily attendance reminders
 */
const functions = require('firebase-functions');

exports.sendDailyAttendanceReminder = functions.pubsub
  .schedule('0 8 * * 1-5') // 8 AM on weekdays
  .timeZone('America/New_York') // Adjust to your timezone
  .onRun(async (context) => {
    console.log('Starting daily attendance reminder job...');
    
    try {
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'student')
        .get();

      const promises = [];
      
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmToken) {
          promises.push(
            exports.sendNotificationToToken(
              userData.fcmToken,
              'Time to Clock In! ⏰',
              'Don\'t forget to clock in for your attendance today.',
              { 
                type: 'clock_in',
                userId: doc.id
              }
            )
          );
        }
      });

      await Promise.all(promises);
      console.log(`✅ Sent ${promises.length} attendance reminders`);
      return null;
    } catch (error) {
      console.error('❌ Error sending attendance reminders:', error);
      throw error;
    }
  });

/**
 * Cloud Function to send clock-out reminders
 */
exports.sendDailyClockOutReminder = functions.pubsub
  .schedule('55 15 * * 1-5') // 3:55 PM on weekdays
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Starting daily clock-out reminder job...');
    
    try {
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('role', '==', 'student')
        .get();

      const promises = [];
      
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmToken) {
          promises.push(
            exports.sendNotificationToToken(
              userData.fcmToken,
              'Time to Clock Out! 🏃‍♂️',
              'Remember to clock out before leaving today.',
              { 
                type: 'clock_out',
                userId: doc.id
              }
            )
          );
        }
      });

      await Promise.all(promises);
      console.log(`✅ Sent ${promises.length} clock-out reminders`);
      return null;
    } catch (error) {
      console.error('❌ Error sending clock-out reminders:', error);
      throw error;
    }
  });

/**
 * Cloud Function to send note due date reminders
 */
exports.sendNoteDueReminders = functions.pubsub
  .schedule('0 9 * * *') // 9 AM daily
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Starting note due reminders job...');
    
    try {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);
      
      const dayAfterTomorrow = new Date(tomorrow);
      dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);

      // Query notes due tomorrow
      const notesQuery = admin.firestore()
        .collectionGroup('notes')
        .where('dueDate', '>=', admin.firestore.Timestamp.fromDate(tomorrow))
        .where('dueDate', '<', admin.firestore.Timestamp.fromDate(dayAfterTomorrow));

      const notesSnapshot = await notesQuery.get();
      const promises = [];

      for (const noteDoc of notesSnapshot.docs) {
        const noteData = noteDoc.data();
        const noteRef = noteDoc.ref;
        const userDoc = await noteRef.parent.parent.get();
        
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) {
            promises.push(
              exports.sendNotificationToToken(
                userData.fcmToken,
                'Note Due Tomorrow 📝',
                `Your note "${noteData.title}" is due tomorrow.`,
                { 
                  type: 'note_due',
                  noteId: noteDoc.id,
                  targetId: noteDoc.id,
                  userId: userDoc.id
                }
              )
            );
          }
        }
      }

      await Promise.all(promises);
      console.log(`✅ Sent ${promises.length} note due reminders`);
      return null;
    } catch (error) {
      console.error('❌ Error sending note due reminders:', error);
      throw error;
    }
  });
