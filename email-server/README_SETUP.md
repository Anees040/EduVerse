# Firebase Service Account Setup for Password Reset

## Why is this needed?
To reset user passwords server-side (without requiring them to click a link), we need Firebase Admin SDK which requires a service account key.

## Steps to get your Service Account Key:

1. Go to the [Firebase Console](https://console.firebase.google.com)
2. Select your project (EduVerse)
3. Click the **Settings** gear icon (⚙️) in the top left
4. Select **Project settings**
5. Go to the **Service accounts** tab
6. Click **Generate new private key**
7. Click **Generate key** to download the JSON file
8. **IMPORTANT**: Rename the downloaded file to `serviceAccountKey.json`
9. Move it to the `email-server` folder (same folder as this README)

## Security Warning ⚠️
- **NEVER** commit `serviceAccountKey.json` to version control
- The file is already added to `.gitignore`
- Keep this file secure as it has full access to your Firebase project

## Starting the Email Server

After placing the service account key:

```bash
cd email-server
npm install  # Only needed first time
npm start
```

The server will show:
- ✅ Firebase Admin SDK initialized - Password reset will work
- ⚠️ Firebase Admin SDK not initialized - Will fallback to Firebase reset link

## Without Service Account (Fallback)
If no service account is configured, the password reset will use Firebase's standard email link approach, which requires users to click a link in their email.
