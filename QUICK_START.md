# 🚀 Quick Start Guide - EduVerse Authentication Update

## What's Been Added?

### ✅ 1. Professional OAuth Buttons
- **Students**: Google + GitHub buttons with real logos
- **Teachers**: Google button only
- Fully functional and integrated with Firebase

### ✅ 2. Email Verification System
- 6-digit code sent to email
- Professional HTML email template
- Verification required before signup
- Checkmark (✓) indicator when verified

### ✅ 3. Secure Forgot Password
- Email verification required
- Multi-step security process
- No more "dummy" functionality

### ✅ 4. Database Security Rules
- Users can only access their own data
- Role-based permissions
- Protection against unauthorized access

---

## 📋 Before You Start

**Dependencies have been installed ✅**

You need to configure:
1. ☐ SMTP for email sending
2. ☐ GitHub OAuth (for student login)
3. ☐ Google OAuth
4. ☐ Firebase Security Rules

---

## 1️⃣ Configure SMTP (Email Verification)

### Option A: Gmail (Easiest)

1. **Enable 2-Factor Authentication**:
   - Go to https://myaccount.google.com/security
   - Turn on 2-Step Verification

2. **Create App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and your device
   - Click "Generate"
   - Copy the 16-character password

3. **Update `.env` file**:
   ```env
   SMTP_EMAIL=your-email@gmail.com
   SMTP_PASSWORD=xxxx xxxx xxxx xxxx  # Your 16-char App Password
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   ```

### Option B: Other Providers

- **Outlook**: `smtp.office365.com:587`
- **Yahoo**: `smtp.mail.yahoo.com:587`

---

## 2️⃣ Configure GitHub OAuth (Students Only)

1. **Create GitHub OAuth App**:
   - Go to https://github.com/settings/developers
   - Click "New OAuth App"
   - Fill in:
     - **Application name**: EduVerse
     - **Homepage URL**: `http://localhost` (for development)
     - **Authorization callback URL**: Leave blank for now

2. **Configure Firebase**:
   - Firebase Console → Authentication → Sign-in method
   - Enable "GitHub"
   - Copy the **callback URL** from Firebase
   - Paste Client ID and Client Secret from GitHub
   
3. **Update GitHub OAuth App**:
   - Go back to GitHub OAuth settings
   - Update "Authorization callback URL" with Firebase callback URL

---

## 3️⃣ Configure Google OAuth

### For Android:

1. **Get SHA-1 Key**:
   ```powershell
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 key from the output

2. **Add to Firebase**:
   - Firebase Console → Project Settings
   - Select your Android app
   - Add SHA-1 fingerprint
   - Download updated `google-services.json`
   - Replace in `android/app/` folder

### For All Platforms:

1. **Enable Google Sign-In**:
   - Firebase Console → Authentication → Sign-in method
   - Enable "Google"
   - Add support email

---

## 4️⃣ Deploy Firebase Security Rules

### Quick Deploy (Recommended):

```powershell
# Make sure you're in the project root
cd "c:\Users\Anees\Desktop\EduVerse"

# Login to Firebase
firebase login

# Deploy the rules
firebase deploy --only database
```

### Manual Deploy:

1. Go to https://console.firebase.google.com/
2. Select "eduverse-8780a" project
3. Click "Realtime Database"
4. Click "Rules" tab
5. Copy content from `database.rules.json`
6. Paste and click "Publish"

---

## 5️⃣ Test the Application

```powershell
flutter run
```

### Test Checklist:

#### Email Verification:
1. ☐ Go to Register screen
2. ☐ Enter email address
3. ☐ Click "Send Verification Code"
4. ☐ Check your email inbox
5. ☐ Enter the 6-digit code
6. ☐ Click "Verify Code"
7. ☐ See checkmark (✓) appear
8. ☐ Complete registration

#### OAuth Login (Student):
1. ☐ Go to Sign In screen
2. ☐ Select "Student"
3. ☐ Click "Continue with Google"
4. ☐ Complete Google sign-in
5. ☐ Should navigate to student home
6. ☐ Try "Continue with GitHub"
7. ☐ Complete GitHub sign-in

#### OAuth Login (Teacher):
1. ☐ Go to Sign In screen
2. ☐ Select "Teacher"
3. ☐ See only Google button (no GitHub)
4. ☐ Click "Continue with Google"
5. ☐ Should navigate to teacher home

#### Forgot Password:
1. ☐ Click "Forgot Password?"
2. ☐ Enter email
3. ☐ Click "Send Code"
4. ☐ Check email for code
5. ☐ Enter 6-digit code
6. ☐ Click "Verify Code"
7. ☐ Should show success message

---

## 🔧 Development Without SMTP

If you haven't configured SMTP yet:
- Verification codes will print to the console
- Look for: `Verification code for user@example.com: 123456`
- Use these codes for testing

---

## 🐛 Troubleshooting

### Emails Not Sending?
- ✓ Check `.env` file has correct credentials
- ✓ Verify Gmail App Password (not regular password)
- ✓ Check spam/junk folder
- ✓ Look for verification code in console logs

### Google Sign-In Not Working?
- ✓ Check SHA-1 key is added to Firebase
- ✓ Download latest `google-services.json`
- ✓ Enable Google provider in Firebase Console
- ✓ Verify OAuth consent screen is configured

### GitHub Sign-In Not Working?
- ✓ Check callback URL matches Firebase
- ✓ Verify Client ID and Secret in Firebase
- ✓ Enable GitHub provider in Firebase Console
- ✓ Check GitHub OAuth app is active

### Database Permission Denied?
- ✓ Deploy security rules: `firebase deploy --only database`
- ✓ Verify rules in Firebase Console
- ✓ Check user is authenticated
- ✓ Ensure user UID matches data path

---

## 📂 Important Files

### New Files Created:
- `lib/services/email_verification_service.dart` - Email verification logic
- `lib/views/register_screen_with_verification.dart` - New signup screen
- `database.rules.json` - Database security rules
- `firestore.rules` - Firestore security rules
- `SETUP_INSTRUCTIONS.md` - Detailed setup guide
- `SECURITY_RULES_GUIDE.md` - Security documentation
- `CHANGES_SUMMARY.md` - Complete changes overview

### Modified Files:
- `lib/views/signin_screen.dart` - Added OAuth buttons
- `lib/services/auth_service.dart` - Added OAuth methods
- `pubspec.yaml` - Added new dependencies
- `.env` - Added SMTP configuration
- `firebase.json` - Added rules references

---

## 🎯 Next Steps

1. **Configure SMTP** (for email verification to work)
2. **Set up OAuth providers** (Google + GitHub)
3. **Deploy security rules** (protect your database)
4. **Test all features** (use the checklist above)
5. **Review documentation** (for detailed information)

---

## 📚 Additional Documentation

- **Complete Setup**: See `SETUP_INSTRUCTIONS.md`
- **Security Guide**: See `SECURITY_RULES_GUIDE.md`
- **All Changes**: See `CHANGES_SUMMARY.md`

---

## ✅ Quick Verification

Run this command to check everything is set up:

```powershell
# Check dependencies
flutter doctor

# Verify Firebase CLI
firebase --version

# Test database connection
firebase database:get / --project eduverse-8780a
```

---

## 🆘 Need Help?

1. Check the documentation files
2. Review Firebase Console logs
3. Check Flutter console output
4. Verify all configuration steps
5. Test with development mode (console logs)

---

**Your app now has professional authentication with email verification and secure database rules!** 🎉

**Estimated setup time**: 15-30 minutes
**Difficulty**: Intermediate

Remember:
- Test in development mode first
- Deploy security rules before production
- Keep SMTP credentials secure
- Monitor Firebase usage regularly
