/**
 * EduVerse Email Server - Local proxy for Mailjet and Firebase Admin
 * Run with: node server.js
 * 
 * Endpoints:
 * - POST /send-verification - Send verification code email
 * - POST /reset-password - Reset user password (uses Firebase Admin SDK)
 * - POST /send-password-changed - Send password changed confirmation email
 */

const http = require('http');
const https = require('https');

// Firebase Admin SDK for password reset
const admin = require('firebase-admin');

// Initialize Firebase Admin (uses default credentials when running locally)
// For production, you need to set GOOGLE_APPLICATION_CREDENTIALS env variable
// Or download a service account key from Firebase Console
let firebaseInitialized = false;
try {
  // Try to initialize with service account if available
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://eduverse-8780a-default-rtdb.firebaseio.com'
  });
  firebaseInitialized = true;
  console.log('✅ Firebase Admin SDK initialized with service account');
} catch (e) {
  // Try application default credentials
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      databaseURL: 'https://eduverse-8780a-default-rtdb.firebaseio.com'
    });
    firebaseInitialized = true;
    console.log('✅ Firebase Admin SDK initialized with default credentials');
  } catch (e2) {
    console.log('⚠️ Firebase Admin SDK not initialized. Password reset via server disabled.');
    console.log('   To enable: Download serviceAccountKey.json from Firebase Console');
    console.log('   Place it in the email-server folder');
  }
}

const PORT = 3001;

// Mailjet credentials
const MAILJET_API_KEY = '63e6d1a69bb4d7beb2d3696db72a5ac1';
const MAILJET_API_SECRET = 'bdce6bf22b047471516a019b389378ef';
const FROM_EMAIL = 'noreply@eduverse-official.me';
const FROM_NAME = 'EduVerse Team';

// Helper function to send email via Mailjet
function sendEmailViaMailjet(to, name, subject, htmlContent, textContent, callback) {
  const emailBody = JSON.stringify({
    Messages: [{
      From: { Email: FROM_EMAIL, Name: FROM_NAME },
      To: [{ Email: to, Name: name || to.split('@')[0] }],
      Subject: subject,
      HTMLPart: htmlContent,
      TextPart: textContent
    }]
  });

  const auth = Buffer.from(`${MAILJET_API_KEY}:${MAILJET_API_SECRET}`).toString('base64');

  const options = {
    hostname: 'api.mailjet.com',
    port: 443,
    path: '/v3.1/send',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${auth}`,
      'Content-Length': Buffer.byteLength(emailBody)
    }
  };

  const mailjetReq = https.request(options, (mailjetRes) => {
    let responseData = '';
    mailjetRes.on('data', chunk => { responseData += chunk; });
    mailjetRes.on('end', () => {
      callback(mailjetRes.statusCode === 200 ? null : responseData, responseData);
    });
  });

  mailjetReq.on('error', (error) => {
    callback(error.message);
  });

  mailjetReq.write(emailBody);
  mailjetReq.end();
}

const server = http.createServer((req, res) => {
  // Enable CORS for all origins
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // ==== SEND VERIFICATION CODE ====
  if (req.method === 'POST' && req.url === '/send-verification') {
    let body = '';

    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', () => {
      try {
        const { to, code, name } = JSON.parse(body);

        if (!to || !code) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, error: 'Missing to or code' }));
          return;
        }

        const htmlContent = `
<!DOCTYPE html>
<html>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎓 EduVerse</h1>
      <p style="color: rgba(255, 255, 255, 0.9); margin-top: 8px; font-size: 14px;">Your Learning Journey Starts Here</p>
    </div>
    <div style="padding: 40px 30px;">
      <h2 style="color: #333333; margin-top: 0;">Hello! 👋</h2>
      <p style="color: #666666; font-size: 16px; line-height: 1.6;">
        Thank you for registering with EduVerse! Please verify your email using the code below:
      </p>
      <div style="background-color: #f8f9fa; border: 2px dashed #667eea; border-radius: 8px; padding: 25px; text-align: center; margin: 30px 0;">
        <p style="color: #666666; margin: 0 0 10px 0; font-size: 14px;">Your Verification Code</p>
        <h1 style="color: #667eea; margin: 0; font-size: 36px; letter-spacing: 8px; font-weight: bold;">${code}</h1>
      </div>
      <p style="color: #666666; font-size: 14px; line-height: 1.6;">
        This code will expire in <strong>10 minutes</strong>.
      </p>
    </div>
    <div style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eee;">
      <p style="color: #999999; font-size: 12px; margin: 0;">© 2026 EduVerse. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`;

        const textContent = `Your EduVerse verification code is: ${code}. This code expires in 10 minutes.`;

        sendEmailViaMailjet(to, name, 'EduVerse - Email Verification Code', htmlContent, textContent, (error) => {
          if (error) {
            console.error('Mailjet error:', error);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: false, error: error }));
          } else {
            console.log(`📧 Verification email sent to ${to}`);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: true, message: 'Email sent!' }));
          }
        });

      } catch (e) {
        console.error('Parse error:', e);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Invalid JSON' }));
      }
    });
  }
  // ==== RESET PASSWORD ====
  else if (req.method === 'POST' && req.url === '/reset-password') {
    let body = '';

    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', async () => {
      try {
        const { email, newPassword } = JSON.parse(body);

        if (!email || !newPassword) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, error: 'Missing email or newPassword' }));
          return;
        }

        if (!firebaseInitialized) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            success: false, 
            error: 'Firebase Admin SDK not initialized. Please configure serviceAccountKey.json' 
          }));
          return;
        }

        const normalizedEmail = email.toLowerCase().trim();
        const emailKey = normalizedEmail.replace(/\./g, '_').replace(/@/g, '_at_');

        // === RATE LIMITING: Check if user has exceeded 2 resets per week ===
        const db = admin.database();
        const rateLimitRef = db.ref(`password_reset_attempts/${emailKey}`);
        const rateLimitSnapshot = await rateLimitRef.once('value');
        
        const oneWeekMs = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
        const currentTime = Date.now();
        
        if (rateLimitSnapshot.exists()) {
          const attemptsData = rateLimitSnapshot.val();
          const attempts = attemptsData.attempts || [];
          
          // Filter to only count attempts within the last week
          const recentAttempts = attempts.filter(timestamp => {
            return (currentTime - timestamp) < oneWeekMs;
          });
          
          if (recentAttempts.length >= 2) {
            // Calculate when the oldest attempt will expire
            const oldestAttempt = Math.min(...recentAttempts);
            const resetAvailableAt = new Date(oldestAttempt + oneWeekMs);
            const daysLeft = Math.ceil((oldestAttempt + oneWeekMs - currentTime) / (24 * 60 * 60 * 1000));
            
            res.writeHead(429, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
              success: false, 
              error: `You have reached the maximum of 2 password resets per week. Please try again in ${daysLeft} day(s).`,
              rateLimitExceeded: true,
              resetAvailableAt: resetAvailableAt.toISOString()
            }));
            return;
          }
        }
        // === END RATE LIMITING CHECK ===

        // Verify that the email was recently verified in our database
        const verificationRef = db.ref(`verification_codes/${emailKey}`);
        const verificationSnapshot = await verificationRef.once('value');

        if (!verificationSnapshot.exists()) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            success: false, 
            error: 'No verification found. Please verify your email first.' 
          }));
          return;
        }

        const verificationData = verificationSnapshot.val();

        // Check if email was verified
        if (!verificationData.verified) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            success: false, 
            error: 'Email not verified. Please complete verification first.' 
          }));
          return;
        }

        // Check if verification is recent (within 15 minutes)
        const currentTime = Date.now();
        const verificationTime = verificationData.timestamp || 0;
        const fifteenMinutes = 15 * 60 * 1000;

        if (currentTime - verificationTime > fifteenMinutes) {
          await verificationRef.remove();
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ 
            success: false, 
            error: 'Verification expired. Please start the password reset process again.' 
          }));
          return;
        }

        // Get the user by email
        let userRecord;
        try {
          userRecord = await admin.auth().getUserByEmail(normalizedEmail);
        } catch (authError) {
          if (authError.code === 'auth/user-not-found') {
            res.writeHead(404, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
              success: false, 
              error: 'No account found with this email address.' 
            }));
            return;
          }
          throw authError;
        }

        // Update the password using Firebase Admin SDK
        await admin.auth().updateUser(userRecord.uid, {
          password: newPassword
        });

        // === RECORD RATE LIMIT: Track this password reset attempt ===
        const rateLimitSnapshot2 = await rateLimitRef.once('value');
        let attempts = [];
        if (rateLimitSnapshot2.exists()) {
          const data = rateLimitSnapshot2.val();
          attempts = data.attempts || [];
          // Only keep attempts from the last week
          attempts = attempts.filter(timestamp => (currentTime - timestamp) < oneWeekMs);
        }
        attempts.push(currentTime);
        await rateLimitRef.set({ 
          email: normalizedEmail,
          attempts: attempts,
          lastAttempt: currentTime
        });
        console.log(`📊 Password reset attempt recorded for ${normalizedEmail}. Total attempts this week: ${attempts.length}`);
        // === END RECORD RATE LIMIT ===

        // Clean up the verification code
        await verificationRef.remove();

        console.log(`✅ Password successfully reset for user: ${normalizedEmail}`);

        // Send password changed confirmation email
        const changeTime = new Date().toLocaleString('en-US', { 
          timeZone: 'UTC', 
          dateStyle: 'full', 
          timeStyle: 'short' 
        }) + ' UTC';

        const userName = userRecord.displayName || normalizedEmail.split('@')[0];

        const htmlContent = `
<!DOCTYPE html>
<html>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎓 EduVerse</h1>
      <p style="color: rgba(255, 255, 255, 0.9); margin-top: 8px; font-size: 14px;">Your Learning Journey Starts Here</p>
    </div>
    <div style="padding: 40px 30px;">
      <div style="text-align: center; margin-bottom: 30px;">
        <span style="font-size: 48px;">✅</span>
      </div>
      <h2 style="color: #333333; margin-top: 0; text-align: center;">Password Changed Successfully</h2>
      <p style="color: #666666; font-size: 16px; line-height: 1.6;">
        Hello, ${userName}!
      </p>
      <p style="color: #666666; font-size: 16px; line-height: 1.6;">
        This email confirms that your EduVerse account password was successfully changed on <strong>${changeTime}</strong>.
      </p>
      <div style="background-color: #e8f4fd; border-left: 4px solid #667eea; padding: 15px 20px; margin: 25px 0; border-radius: 0 8px 8px 0;">
        <p style="color: #333333; margin: 0; font-size: 14px;">
          <strong>🔒 Security Notice:</strong> If you made this change, you can safely ignore this email. Your account is secure.
        </p>
      </div>
      <p style="color: #666666; font-size: 14px; line-height: 1.6;">
        If you did <strong>not</strong> make this change, please reset your password immediately.
      </p>
    </div>
    <div style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eee;">
      <p style="color: #999999; font-size: 12px; margin: 0;">© 2026 EduVerse. All rights reserved.</p>
    </div>
  </div>
</body>
</html>`;

        const textContent = `Password Changed Successfully

Hello, ${userName}!

This email confirms that your EduVerse account password was successfully changed on ${changeTime}.

If you made this change, you can safely ignore this email. Your account is secure.

If you did NOT make this change, please reset your password immediately.

© 2026 EduVerse. All rights reserved.`;

        sendEmailViaMailjet(normalizedEmail, userName, 'Your EduVerse Password Has Been Changed', htmlContent, textContent, (emailError) => {
          if (emailError) {
            console.error('Failed to send password changed email:', emailError);
          } else {
            console.log(`📧 Password changed confirmation email sent to ${normalizedEmail}`);
          }
        });

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
          success: true, 
          message: 'Password updated successfully! You can now sign in with your new password.' 
        }));

      } catch (e) {
        console.error('Password reset error:', e);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: e.message || 'Failed to reset password' }));
      }
    });
  }
  else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

server.listen(PORT, () => {
  console.log('═══════════════════════════════════════════════════');
  console.log('🚀 EduVerse Email Server running on port ' + PORT);
  console.log('📧 Endpoints:');
  console.log('   POST http://localhost:' + PORT + '/send-verification');
  console.log('   POST http://localhost:' + PORT + '/reset-password');
  console.log('═══════════════════════════════════════════════════');
});
