// Import the Firebase scripts required for Firebase Messaging.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Initialize Firebase in the service worker.
// 🔹 Replace every placeholder below with your actual Firebase project values.
//    These must match the config you pass to Firebase.initializeApp() in Dart.

firebase.initializeApp({
  apiKey: "AIzaSyCJHWjUJtZQjZjoZiWpQomrN0MVOicrVtk",
  authDomain: "student-reminder-xx-16738.firebaseapp.com",
  projectId: "student-reminder-xx-16738",
  storageBucket: "student-reminder-xx-16738.firebasestorage.app",
  messagingSenderId: "562730922018",
  appId: "1:562730922018:web:8fefad6d11fa775b2d5a7b"
  // Optional: measurementId: "G-XXXXXXXXXX"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

// Optional: Handle background push messages here.
messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  // Customize notification here:
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png' // your app icon
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
