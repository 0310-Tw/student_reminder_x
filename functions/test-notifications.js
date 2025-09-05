// file: functions/test-notifications.js
const admin = require('firebase-admin');

// Download service account key from Firebase Console and place here
// Go to: Project Settings > Service Accounts > Generate New Private Key
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Replace with actual FCM token from your app logs
const testToken = 'REPLACE_WITH_ACTUAL_FCM_TOKEN';

async function runTests() {
  console.log('🧪 Testing notification sending...\n');
  
  try {
    // Test 1: Basic notification
    console.log('📱 Test 1: Basic notification');
    const response1 = await admin.messaging().send({
      notification: {
        title: 'Test Notification 🧪',
        body: 'Basic test message from Cloud Functions'
      },
      token: testToken,
    });
    console.log('✅ Basic notification sent:', response1);
    
    // Test 2: Data-only message
    console.log('\n📱 Test 2: Data-only message');
    const response2 = await admin.messaging().send({
      data: {
        type: 'test',
        message: 'Data only test',
        timestamp: Date.now().toString()
      },
      token: testToken,
    });
    console.log('✅ Data-only message sent:', response2);
    
    // Test 3: Topic message (subscribe to topic first in app)
    console.log('\n📱 Test 3: Topic message');
    const response3 = await admin.messaging().send({
      notification: {
        title: 'Topic Test 📢',
        body: 'Message to all students'
      },
      data: {
        type: 'topic_test'
      },
      topic: 'students',
    });
    console.log('✅ Topic message sent:', response3);
    
    // Test 4: Attendance reminder
    console.log('\n📱 Test 4: Attendance reminder');
    const response4 = await admin.messaging().send({
      notification: {
        title: 'Time to Clock In! ⏰',
        body: 'Don\'t forget to clock in for your attendance today.'
      },
      data: {
        type: 'clock_in',
        timestamp: Date.now().toString()
      },
      token: testToken,
    });
    console.log('✅ Attendance reminder sent:', response4);
    
    console.log('\n🎉 All tests completed successfully!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.code) {
      console.error('Error code:', error.code);
    }
    
    // Common error solutions
    if (error.message.includes('not found')) {
      console.log('\n💡 Solution: Make sure you have the correct FCM token');
      console.log('   Get it from your app logs when NotificationService initializes');
    }
    if (error.message.includes('service account')) {
      console.log('\n💡 Solution: Download service account key from Firebase Console');
      console.log('   Project Settings > Service Accounts > Generate New Private Key');
      console.log('   Save as service-account-key.json in functions folder');
    }
  }
}

async function getUserTokens() {
  console.log('\n🔍 Fetching user FCM tokens...\n');
  
  try {
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('fcmToken', '!=', null)
      .limit(5)
      .get();

    if (usersSnapshot.empty) {
      console.log('❌ No users with FCM tokens found');
      console.log('💡 Make sure users have logged in and granted notification permissions');
      return;
    }

    console.log('📋 Users with FCM tokens:');
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      console.log(`- ${userData.firstName} ${userData.lastName} (${userData.email})`);
      console.log(`  Token: ${userData.fcmToken?.substring(0, 30)}...`);
      console.log(`  Role: ${userData.role}`);
      console.log('');
    });
    
  } catch (error) {
    console.error('❌ Error fetching tokens:', error.message);
  }
}

// Run the tests
runTests()
  .then(() => getUserTokens())
  .then(() => process.exit(0))
  .catch(error => {
    console.error('💥 Unhandled error:', error);
    process.exit(1);
  });
