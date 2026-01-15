/**
 * EduVerse Email Server - Local proxy for Mailjet
 * Run with: node server.js
 */

const http = require('http');
const https = require('https');

const PORT = 3001;

// Mailjet credentials
const MAILJET_API_KEY = '63e6d1a69bb4d7beb2d3696db72a5ac1';
const MAILJET_API_SECRET = 'bdce6bf22b047471516a019b389378ef';
const FROM_EMAIL = 'noreply@eduverse-official.me';
const FROM_NAME = 'EduVerse Team';

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

  // Only handle POST to /send-verification
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

        const emailBody = JSON.stringify({
          Messages: [{
            From: { Email: FROM_EMAIL, Name: FROM_NAME },
            To: [{ Email: to, Name: name || to.split('@')[0] }],
            Subject: 'EduVerse - Email Verification Code',
            HTMLPart: `
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
</html>`,
            TextPart: `Your EduVerse verification code is: ${code}. This code expires in 10 minutes.`
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

          mailjetRes.on('data', chunk => {
            responseData += chunk;
          });

          mailjetRes.on('end', () => {
            console.log(`📧 Email sent to ${to} - Status: ${mailjetRes.statusCode}`);
            
            if (mailjetRes.statusCode === 200) {
              res.writeHead(200, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ success: true, message: 'Email sent!' }));
            } else {
              console.error('Mailjet error:', responseData);
              res.writeHead(500, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ success: false, error: responseData }));
            }
          });
        });

        mailjetReq.on('error', (error) => {
          console.error('Request error:', error);
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ success: false, error: error.message }));
        });

        mailjetReq.write(emailBody);
        mailjetReq.end();

      } catch (e) {
        console.error('Parse error:', e);
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Invalid JSON' }));
      }
    });
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

server.listen(PORT, () => {
  console.log('═══════════════════════════════════════════════════');
  console.log('🚀 EduVerse Email Server running on port ' + PORT);
  console.log('📧 Endpoint: http://localhost:' + PORT + '/send-verification');
  console.log('═══════════════════════════════════════════════════');
});
