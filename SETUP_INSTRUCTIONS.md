# EduVerse Setup Instructions

## New Features Implemented

### 1. OAuth Authentication
- **Students**: Can sign in/up with Google or GitHub
- **Teachers**: Can sign in/up with Google only
- Professional OAuth buttons with proper branding

### 2. Email Verification System
- 6-digit verification code sent to email during signup
- Code expires in 10 minutes
- Resend functionality with countdown timer
- Verified emails show a checkmark ✓ indicator
- Required before account creation

### 3. Enhanced Forgot Password
- Multi-step verification process
- Email verification code required before password reset
- Professional implementation with proper validation

### 4. Secure Firebase Database Rules
- User-specific read/write permissions
- Role-based access control
- Protected collections and data

## Setup Instructions

### Step 1: Install Dependencies

Run the following command in your terminal:

```powershell
flutter pub get
```

### Step 2: Configure SMTP for Email Verification

1. **For Gmail Users** (Recommended):
   - Go to https://myaccount.google.com/security
   - Enable 2-Factor Authentication (2FA)
   - Go to https://myaccount.google.com/apppasswords
   - Create a new App Password for "Mail"
   - Copy the 16-character password

2. **Update `.env` file**:
   Open the `.env` file and update these values:
   ```env
   SMTP_EMAIL=your-email@gmail.com
   SMTP_PASSWORD=your-16-char-app-password
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   ```

3. **For Other Email Providers**:
   - Outlook/Hotmail: `smtp.office365.com` port 587
   - Yahoo: `smtp.mail.yahoo.com` port 587
   - Custom SMTP: Contact your email provider for SMTP settings

### Step 3: Configure GitHub OAuth (For Student Login)

1. Go to GitHub Settings → Developer settings → OAuth Apps
2. Create a new OAuth App:
   - **Application name**: EduVerse
   - **Homepage URL**: `https://your-domain.com` (or localhost for development)
   - **Authorization callback URL**: 
     - For Android: `com.eduverse.app:/oauth2redirect`
     - For iOS: `com.eduverse.app://oauth2redirect`
     - For Web: `https://your-domain.com/oauth2redirect`
3. Copy the Client ID and Client Secret

4. Add to Firebase Console:
   - Go to Firebase Console → Authentication → Sign-in method
   - Enable GitHub provider
   - Paste Client ID and Client Secret
   - Copy the authorization callback URL from Firebase
   - Update your GitHub OAuth app with this callback URL

### Step 4: Configure Google OAuth

1. Go to Google Cloud Console (https://console.cloud.google.com/)
2. Select your Firebase project
3. Enable Google Sign-In API
4. Configure OAuth consent screen
5. In Firebase Console → Authentication → Sign-in method
6. Enable Google provider
7. Add your SHA-1 and SHA-256 keys for Android:
   ```powershell
   cd android
   ./gradlew signingReport
   ```

### Step 5: Deploy Firebase Security Rules

Deploy the new security rules to protect your database:

```powershell
# Deploy Realtime Database rules
firebase deploy --only database

# Deploy Firestore rules (if using Firestore)
firebase deploy --only firestore
```

Or manually update rules in Firebase Console:
- Realtime Database: Copy from `database.rules.json`
- Firestore: Copy from `firestore.rules`

### Step 6: Update Android Configuration (for GitHub OAuth)

Add to `android/app/src/main/AndroidManifest.xml` inside `<activity>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="com.eduverse.app"
        android:host="oauth2redirect" />
</intent-filter>
```

### Step 7: Update iOS Configuration (for GitHub OAuth)

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.eduverse.app</string>
        </array>
    </dict>
</array>
```

### Step 8: Run the Application

```powershell
flutter run
```

## Testing Email Verification

### Development Mode
If SMTP is not configured, the verification codes will be printed to the console. You can use these codes for testing.

### Production Mode
Once SMTP is configured, users will receive professional HTML emails with:
- eduVerse branding
- 6-digit verification code
- Expiration time (10 minutes)
- Security warnings

## Database Security Rules Explanation

### Realtime Database Rules
- Users can only read/write their own data
- Courses are readable by all authenticated users
- Only teachers can create/edit courses they own
- Verification codes are write-only (security)

### Firestore Rules
- Similar structure to Realtime Database
- Role-based access control
- Document-level security
- Helper functions for maintainability

## Troubleshooting

### Email Verification Not Working
1. Check `.env` file has correct SMTP credentials
2. Ensure Gmail App Password is used (not regular password)
3. Check console logs for verification codes
4. Verify email address is valid

### GitHub OAuth Not Working
1. Verify callback URL matches Firebase configuration
2. Check GitHub OAuth app settings
3. Ensure Firebase has GitHub provider enabled
4. Check Android/iOS configuration files

### Google OAuth Not Working
1. Verify SHA-1 keys are added to Firebase
2. Check OAuth consent screen is configured
3. Ensure google-services.json is up to date
4. Verify package name matches

### Database Permission Errors
1. Deploy security rules using Firebase CLI
2. Verify user is authenticated before accessing data
3. Check Firebase Console → Database → Rules tab
4. Ensure timestamp rules are correct

## Security Best Practices

1. **Never commit `.env` file** to version control
2. **Use App Passwords** for Gmail, not regular passwords
3. **Enable 2FA** on all service accounts
4. **Regularly rotate** API keys and passwords
5. **Monitor Firebase usage** for suspicious activity
6. **Keep dependencies updated** for security patches

## Features Summary

✅ Student Login/Signup: Google + GitHub OAuth
✅ Teacher Login/Signup: Google OAuth only
✅ Email verification with 6-digit code
✅ Professional HTML email templates
✅ Verified email indicator (✓ checkmark)
✅ Forgot password with email verification
✅ Secure Firebase database rules
✅ Password strength indicator
✅ Form validation and error handling
✅ Responsive UI with dark mode support

## Support

For issues or questions:
1. Check Firebase Console logs
2. Review Flutter console output
3. Verify all configuration steps
4. Check Firebase Authentication dashboard
5. Review database rules in Firebase Console
