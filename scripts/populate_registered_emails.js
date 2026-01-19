/**
 * One-time migration script to populate registered_emails from existing users
 * Run with: node scripts/populate_registered_emails.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../email-server/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://eduverse-8780a-default-rtdb.firebaseio.com'
});

const db = admin.database();

async function migrateEmails() {
  console.log('Starting email migration...\n');
  
  let count = 0;
  
  // Migrate students
  console.log('Processing students...');
  const studentsSnap = await db.ref('student').once('value');
  if (studentsSnap.exists()) {
    const students = studentsSnap.val();
    for (const [uid, data] of Object.entries(students)) {
      if (data.email) {
        const email = data.email.toLowerCase().trim();
        const emailKey = email.replace(/\./g, '_').replace(/@/g, '_at_');
        
        await db.ref(`registered_emails/${emailKey}`).set({
          email: email,
          role: 'student',
          uid: uid,
          registeredAt: data.createdAt || Date.now()
        });
        
        console.log(`  ✅ ${email} (student)`);
        count++;
      }
    }
  }
  
  // Migrate teachers
  console.log('\nProcessing teachers...');
  const teachersSnap = await db.ref('teacher').once('value');
  if (teachersSnap.exists()) {
    const teachers = teachersSnap.val();
    for (const [uid, data] of Object.entries(teachers)) {
      if (data.email) {
        const email = data.email.toLowerCase().trim();
        const emailKey = email.replace(/\./g, '_').replace(/@/g, '_at_');
        
        await db.ref(`registered_emails/${emailKey}`).set({
          email: email,
          role: 'teacher',
          uid: uid,
          registeredAt: data.createdAt || Date.now()
        });
        
        console.log(`  ✅ ${email} (teacher)`);
        count++;
      }
    }
  }
  
  console.log(`\n✅ Migration complete! Migrated ${count} emails.`);
  process.exit(0);
}

migrateEmails().catch(err => {
  console.error('Migration failed:', err);
  process.exit(1);
});
