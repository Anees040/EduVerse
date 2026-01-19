/**
 * EduVerse Email Service - Mailjet via Nodemailer
 * 
 * This module provides email sending functionality using Mailjet SMTP.
 * It uses nodemailer with Mailjet credentials for reliable email delivery.
 */

const nodemailer = require("nodemailer");

// Load environment variables
require("dotenv").config();

/**
 * Create and configure the nodemailer transporter for Mailjet
 */
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "in-v3.mailjet.com",
  port: parseInt(process.env.SMTP_PORT) || 587,
  secure: false, // Use TLS (port 587)
  auth: {
    user: process.env.MAILJET_API_KEY,
    pass: process.env.MAILJET_API_SECRET,
  },
});

/**
 * Send an email using Mailjet
 * 
 * @param {Object} options - Email options
 * @param {string} options.to - Recipient email address
 * @param {string} options.subject - Email subject line
 * @param {string} options.text - Plain text body (optional if html provided)
 * @param {string} options.html - HTML body (optional if text provided)
 * @returns {Promise<Object>} - Nodemailer send result
 */
async function sendEmail({ to, subject, text, html }) {
  if (!to || !subject) {
    throw new Error("Missing required fields: 'to' and 'subject' are required");
  }

  if (!text && !html) {
    throw new Error("Missing email body: provide either 'text' or 'html'");
  }

  const mailOptions = {
    from: process.env.FROM_EMAIL || '"EduVerse Team" <noreply@eduverse-official.me>',
    to,
    subject,
    text,
    html,
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    console.log("Email sent successfully:", info.messageId);
    return {
      success: true,
      messageId: info.messageId,
      response: info.response,
    };
  } catch (error) {
    console.error("Email sending failed:", error.message);
    throw error;
  }
}

/**
 * Send a verification email with a code or link
 * 
 * @param {string} to - Recipient email address
 * @param {string} verificationCode - The verification code or link
 * @param {string} userName - User's name for personalization
 * @returns {Promise<Object>} - Send result
 */
async function sendVerificationEmail(to, verificationCode, userName = "User") {
  const subject = "Verify Your EduVerse Account";
  
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Verify Your Email</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎓 EduVerse</h1>
          <p style="color: rgba(255, 255, 255, 0.9); margin-top: 8px; font-size: 14px;">Your Learning Journey Starts Here</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px 30px;">
          <h2 style="color: #333333; margin-top: 0;">Hello, ${userName}! 👋</h2>
          <p style="color: #666666; font-size: 16px; line-height: 1.6;">
            Welcome to EduVerse! To complete your registration and start your learning journey, please verify your email address using the code below:
          </p>
          
          <!-- Verification Code Box -->
          <div style="background-color: #f8f9fa; border: 2px dashed #667eea; border-radius: 8px; padding: 25px; text-align: center; margin: 30px 0;">
            <p style="color: #666666; margin: 0 0 10px 0; font-size: 14px;">Your Verification Code</p>
            <h1 style="color: #667eea; margin: 0; font-size: 36px; letter-spacing: 8px; font-weight: bold;">${verificationCode}</h1>
          </div>
          
          <p style="color: #666666; font-size: 14px; line-height: 1.6;">
            This code will expire in <strong>10 minutes</strong>. If you didn't create an account with EduVerse, you can safely ignore this email.
          </p>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eee;">
          <p style="color: #999999; font-size: 12px; margin: 0;">
            © 2026 EduVerse. All rights reserved.<br>
            This is an automated message, please do not reply.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Hello, ${userName}!

Welcome to EduVerse! To complete your registration, please verify your email using this code:

${verificationCode}

This code will expire in 10 minutes.

If you didn't create an account with EduVerse, you can safely ignore this email.

© 2026 EduVerse. All rights reserved.
  `;

  return sendEmail({ to, subject, text, html });
}

/**
 * Send a welcome email after successful verification
 * 
 * @param {string} to - Recipient email address
 * @param {string} userName - User's name for personalization
 * @returns {Promise<Object>} - Send result
 */
async function sendWelcomeEmail(to, userName = "User") {
  const subject = "Welcome to EduVerse! 🎉";
  
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Welcome to EduVerse</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎓 EduVerse</h1>
          <p style="color: rgba(255, 255, 255, 0.9); margin-top: 8px; font-size: 14px;">Your Learning Journey Starts Here</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px 30px;">
          <h2 style="color: #333333; margin-top: 0;">Welcome aboard, ${userName}! 🎉</h2>
          <p style="color: #666666; font-size: 16px; line-height: 1.6;">
            Your email has been verified and your account is now active! You're all set to explore everything EduVerse has to offer.
          </p>
          
          <!-- Features -->
          <div style="margin: 30px 0;">
            <h3 style="color: #333333; font-size: 18px;">What you can do now:</h3>
            <ul style="color: #666666; font-size: 14px; line-height: 2;">
              <li>📚 Browse and enroll in courses</li>
              <li>🤖 Chat with our AI learning assistant</li>
              <li>📷 Get homework help with image analysis</li>
              <li>🏆 Track your learning progress</li>
              <li>👥 Connect with other learners</li>
            </ul>
          </div>
          
          <p style="color: #666666; font-size: 14px;">
            If you have any questions, feel free to reach out to our support team.
          </p>
          
          <p style="color: #666666; font-size: 14px;">
            Happy Learning! 📖<br>
            <strong>The EduVerse Team</strong>
          </p>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eee;">
          <p style="color: #999999; font-size: 12px; margin: 0;">
            © 2026 EduVerse. All rights reserved.<br>
            This is an automated message, please do not reply.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Welcome aboard, ${userName}! 🎉

Your email has been verified and your account is now active!

What you can do now:
- Browse and enroll in courses
- Chat with our AI learning assistant
- Get homework help with image analysis
- Track your learning progress
- Connect with other learners

If you have any questions, feel free to reach out to our support team.

Happy Learning!
The EduVerse Team

© 2026 EduVerse. All rights reserved.
  `;

  return sendEmail({ to, subject, text, html });
}

/**
 * Send a password reset email
 * 
 * @param {string} to - Recipient email address
 * @param {string} resetLink - Password reset link
 * @param {string} userName - User's name for personalization
 * @returns {Promise<Object>} - Send result
 */
async function sendPasswordResetEmail(to, resetLink, userName = "User") {
  const subject = "Reset Your EduVerse Password";
  
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Reset Your Password</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎓 EduVerse</h1>
          <p style="color: rgba(255, 255, 255, 0.9); margin-top: 8px; font-size: 14px;">Password Reset Request</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px 30px;">
          <h2 style="color: #333333; margin-top: 0;">Hello, ${userName}!</h2>
          <p style="color: #666666; font-size: 16px; line-height: 1.6;">
            We received a request to reset your password. Click the button below to create a new password:
          </p>
          
          <!-- Reset Button -->
          <div style="text-align: center; margin: 30px 0;">
            <a href="${resetLink}" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">Reset Password</a>
          </div>
          
          <p style="color: #666666; font-size: 14px; line-height: 1.6;">
            This link will expire in <strong>1 hour</strong>. If you didn't request a password reset, you can safely ignore this email.
          </p>
          
          <p style="color: #999999; font-size: 12px; margin-top: 20px;">
            If the button doesn't work, copy and paste this link into your browser:<br>
            <a href="${resetLink}" style="color: #667eea; word-break: break-all;">${resetLink}</a>
          </p>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eee;">
          <p style="color: #999999; font-size: 12px; margin: 0;">
            © 2026 EduVerse. All rights reserved.<br>
            This is an automated message, please do not reply.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Hello, ${userName}!

We received a request to reset your password.

Click the link below to create a new password:
${resetLink}

This link will expire in 1 hour.

If you didn't request a password reset, you can safely ignore this email.

© 2026 EduVerse. All rights reserved.
  `;

  return sendEmail({ to, subject, text, html });
}

/**
 * Send a password changed confirmation email
 * 
 * @param {string} to - Recipient email address
 * @param {string} userName - User's name for personalization
 * @returns {Promise<Object>} - Send result
 */
async function sendPasswordChangedEmail(to, userName = "User") {
  const subject = "Your EduVerse Password Has Been Changed";
  const changeTime = new Date().toLocaleString('en-US', { 
    timeZone: 'UTC', 
    dateStyle: 'full', 
    timeStyle: 'short' 
  }) + ' UTC';
  
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Password Changed</title>
    </head>
    <body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center;">
          <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎓 EduVerse</h1>
          <p style="color: rgba(255, 255, 255, 0.9); margin-top: 8px; font-size: 14px;">Your Learning Journey Starts Here</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px 30px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <div style="display: inline-block; background-color: #d4edda; border-radius: 50%; padding: 20px;">
              <span style="font-size: 48px;">✅</span>
            </div>
          </div>
          
          <h2 style="color: #333333; margin-top: 0; text-align: center;">Password Changed Successfully</h2>
          
          <p style="color: #666666; font-size: 16px; line-height: 1.6;">
            Hello, ${userName}!
          </p>
          
          <p style="color: #666666; font-size: 16px; line-height: 1.6;">
            This email confirms that your EduVerse account password was successfully changed on <strong>${changeTime}</strong>.
          </p>
          
          <!-- Info Box -->
          <div style="background-color: #e8f4fd; border-left: 4px solid #667eea; padding: 15px 20px; margin: 25px 0; border-radius: 0 8px 8px 0;">
            <p style="color: #333333; margin: 0; font-size: 14px;">
              <strong>🔒 Security Notice:</strong> If you made this change, you can safely ignore this email. Your account is secure.
            </p>
          </div>
          
          <p style="color: #666666; font-size: 14px; line-height: 1.6;">
            If you did <strong>not</strong> make this change, please take the following steps immediately:
          </p>
          
          <ul style="color: #666666; font-size: 14px; line-height: 1.8;">
            <li>Reset your password again using the "Forgot Password" option</li>
            <li>Check your account for any unauthorized activity</li>
            <li>Contact our support team if you need assistance</li>
          </ul>
          
          <p style="color: #999999; font-size: 13px; margin-top: 30px; font-style: italic;">
            You're receiving this email because a password change was requested for your EduVerse account (${to}).
          </p>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #f8f9fa; padding: 25px 30px; text-align: center; border-top: 1px solid #eee;">
          <p style="color: #999999; font-size: 12px; margin: 0;">
            © 2026 EduVerse. All rights reserved.<br>
            This is an automated security notification, please do not reply.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Password Changed Successfully

Hello, ${userName}!

This email confirms that your EduVerse account password was successfully changed on ${changeTime}.

SECURITY NOTICE: If you made this change, you can safely ignore this email. Your account is secure.

If you did NOT make this change, please:
- Reset your password again using the "Forgot Password" option
- Check your account for any unauthorized activity
- Contact our support team if you need assistance

You're receiving this email because a password change was requested for your EduVerse account (${to}).

© 2026 EduVerse. All rights reserved.
  `;

  return sendEmail({ to, subject, text, html });
}

module.exports = {
  sendEmail,
  sendVerificationEmail,
  sendWelcomeEmail,
  sendPasswordResetEmail,
  sendPasswordChangedEmail,
  transporter, // Export for testing
};
