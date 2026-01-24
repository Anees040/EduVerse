/**
 * Admin Setup Script for EduVerse
 * 
 * This script sets up an admin user in Firebase Realtime Database.
 * 
 * USAGE:
 * 1. Make sure you have Node.js installed
 * 2. Run: npm install firebase-admin (already done)
 * 3. Run: node scripts/setup_admin.js
 * 
 * The admin email: aneesahfaq040@gmail.com
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin SDK
// Try to use serviceAccountKey.json from email-server folder
let serviceAccount;
try {
  serviceAccount = require('../email-server/serviceAccountKey.json');
} catch (e) {
  console.error('Error: Could not find serviceAccountKey.json');
  console.error('Please make sure email-server/serviceAccountKey.json exists.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://eduverse-8780a-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function setupAdmin() {
  const adminEmail = 'aneesahfaq040@gmail.com';
  const adminPassword = '123456!Anees';
  
  console.log('🔧 Setting up admin for EduVerse...\n');
  
  try {
    // First, try to get the user by email or create one
    let user;
    try {
      user = await admin.auth().getUserByEmail(adminEmail);
      console.log(`✅ Found existing user: ${user.email}`);
      console.log(`   UID: ${user.uid}`);
    } catch (e) {
      // User doesn't exist, create the user
      console.log(`⚠️  User with email ${adminEmail} does not exist.`);
      console.log('   Creating new admin user...');
      
      user = await admin.auth().createUser({
        email: adminEmail,
        password: adminPassword,
        emailVerified: true,
        displayName: 'Admin User'
      });
      
      console.log(`✅ Created new user: ${user.email}`);
      console.log(`   UID: ${user.uid}`);
    }
    
    // Set up admin in Realtime Database
    const adminData = {
      email: adminEmail,
      name: 'Admin User',
      role: 'admin',
      createdAt: Date.now(),
      permissions: {
        manageUsers: true,
        manageCourses: true,
        manageContent: true,
        viewAnalytics: true,
        moderateContent: true,
        exportData: true
      }
    };
    
    await db.ref(`admin/${user.uid}`).set(adminData);
    
    // Also add to registered_emails for consistency
    const emailKey = adminEmail.replace(/\./g, ',');
    await db.ref(`registered_emails/${emailKey}`).set({
      email: adminEmail,
      role: 'admin',
      uid: user.uid,
      createdAt: Date.now()
    });
    
    console.log(`\n✅ Admin setup complete!`);
    console.log(`\n📋 Admin Details:`);
    console.log(`   Email: ${adminEmail}`);
    console.log(`   Password: ${adminPassword}`);
    console.log(`   UID: ${user.uid}`);
    console.log(`   Role: admin`);
    
    console.log('\n🔐 How to login as admin:');
    console.log('   1. Open EduVerse app');
    console.log('   2. Go to Sign In page');
    console.log(`   3. Enter email: ${adminEmail}`);
    console.log(`   4. Enter password: ${adminPassword}`);
    console.log('   5. Click Sign In');
    console.log('   6. You will be automatically redirected to Admin Dashboard!');
    
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error setting up admin:', error.message);
    process.exit(1);
  }
}

setupAdmin();
