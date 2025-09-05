"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendEveningReminder = exports.sendMorningReminder = exports.sendTopicNotification = exports.sendPushNotification = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
// Send notification to a single device
exports.sendPushNotification = functions.runWith({
    memory: '256MB',
    timeoutSeconds: 60
}).https.onRequest(async (req, res) => {
    // Enable CORS for web testing
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    const { title, body, token } = req.body;
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
    }
    catch (error) {
        res.status(500).send({
            success: false,
            error: "Failed to send notification",
            details: error.message || error,
        });
    }
});
// Send notification to a topic
exports.sendTopicNotification = functions.https.onRequest(async (req, res) => {
    // Enable CORS for web testing
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
    }
    const { title, body, topic } = req.body;
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
    }
    catch (error) {
        res.status(500).send({
            success: false,
            error: "Failed to send topic notification",
            details: error.message || error,
        });
    }
});
// Scheduled functions for daily reminders
exports.sendMorningReminder = functions.pubsub.schedule('0 8 * * 1-5')
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
    }
    catch (error) {
        console.error('Error sending morning reminder:', error);
    }
});
exports.sendEveningReminder = functions.pubsub.schedule('55 15 * * 1-5')
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
    }
    catch (error) {
        console.error('Error sending evening reminder:', error);
    }
});
