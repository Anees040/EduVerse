# Firebase Security Rules Quick Reference

## Current Security Issues (BEFORE Fix)
⚠️ **CRITICAL**: Your database currently has open rules that allow:
- Any logged-in user to read your **entire database**
- Any logged-in user to write to **any location** in your database
- Potential data breaches and unauthorized access
- Malicious users can delete or modify other users' data

## Security Rules Implementation (AFTER Fix)

### Realtime Database Rules
Located in: `database.rules.json`

**Key Features**:
- ✅ Users can only access their own student/teacher profile
- ✅ Courses are readable by all authenticated users
- ✅ Only teachers who own courses can edit them
- ✅ Bookmarks, chat history, and notifications are user-specific
- ✅ Verification codes are write-only (not readable)
- ✅ Default deny all other access

### Firestore Rules
Located in: `firestore.rules`

**Key Features**:
- ✅ Document-level security
- ✅ Helper functions for cleaner rules
- ✅ Role-based access control
- ✅ Owner verification for all user data
- ✅ Teacher verification for course creation

## How to Deploy Rules

### Option 1: Firebase CLI (Recommended)

```powershell
# Make sure you're logged in to Firebase
firebase login

# Deploy Realtime Database rules
firebase deploy --only database

# Deploy Firestore rules
firebase deploy --only firestore

# Or deploy both at once
firebase deploy --only database,firestore
```

### Option 2: Firebase Console (Manual)

**For Realtime Database**:
1. Go to https://console.firebase.google.com/
2. Select your project: eduverse-8780a
3. Click "Realtime Database" in the left menu
4. Click the "Rules" tab
5. Copy the content from `database.rules.json`
6. Paste it into the rules editor
7. Click "Publish"

**For Firestore** (if you're using it):
1. Go to Firebase Console
2. Click "Firestore Database" in the left menu
3. Click the "Rules" tab
4. Copy the content from `firestore.rules`
5. Paste it into the rules editor
6. Click "Publish"

## Rule Examples Explained

### Student/Teacher Data Protection
```json
"student": {
  "$uid": {
    ".read": "$uid === auth.uid",
    ".write": "$uid === auth.uid"
  }
}
```
This means: Students can ONLY read and write their own profile. User with ID "abc123" can ONLY access "student/abc123", not other users.

### Course Access Control
```json
"courses": {
  ".read": "auth != null",
  "$courseId": {
    ".write": "auth != null && (root.child('teacher').child(auth.uid).exists() || root.child('courses').child($courseId).child('teacherId').val() === auth.uid)"
  }
}
```
This means:
- Anyone logged in can READ courses
- Only teachers can CREATE courses
- Only the teacher who created a course can UPDATE/DELETE it

### Private Data Protection
```json
"chat_history": {
  "$uid": {
    ".read": "$uid === auth.uid",
    ".write": "$uid === auth.uid"
  }
}
```
This means: Chat history is completely private. Each user can only access their own chat history.

## Testing Your Rules

### Test in Firebase Console
1. Go to Realtime Database → Rules tab
2. Click "Rules Playground" (simulator icon)
3. Try different operations:
   - Read as different users
   - Write as different users
   - Verify your rules work correctly

### Test in Your App
After deploying rules:
1. Create a student account
2. Try to access another student's data (should fail)
3. Create a teacher account
4. Try to create a course (should work)
5. As a student, try to edit a course (should fail)
6. As the teacher who created a course, try to edit it (should work)

## Common Rule Patterns

### Read-Only for All Authenticated Users
```json
".read": "auth != null",
".write": false
```

### Owner-Only Access
```json
".read": "$uid === auth.uid",
".write": "$uid === auth.uid"
```

### Public Read, Authenticated Write
```json
".read": true,
".write": "auth != null"
```

### Role-Based Write
```json
".write": "auth != null && root.child('teacher').child(auth.uid).exists()"
```

## Security Checklist

After deploying rules, verify:
- [ ] Students cannot read other students' profiles
- [ ] Students cannot read teachers' private data
- [ ] Students cannot create/edit courses
- [ ] Teachers can create courses
- [ ] Teachers can only edit their own courses
- [ ] Everyone can read course listings
- [ ] Chat history is private to each user
- [ ] Bookmarks are private to each user
- [ ] Verification codes are secure

## Monitoring and Alerts

1. **Set up Firebase Alerts**:
   - Go to Firebase Console → Alerts
   - Enable "Security rules violation" alerts
   - Add your email for notifications

2. **Check Firebase Usage**:
   - Monitor unusual spikes in database reads/writes
   - Review authentication logs regularly
   - Check for suspicious access patterns

3. **Regular Audits**:
   - Review rules every few months
   - Update rules as new features are added
   - Test rules with different user scenarios

## Emergency: If Your Data is Compromised

If you suspect unauthorized access:
1. **Immediately deploy strict rules**:
   ```json
   {
     "rules": {
       ".read": false,
       ".write": false
     }
   }
   ```
2. **Check Firebase Authentication logs**
3. **Review database activity in Firebase Console**
4. **Reset affected user passwords**
5. **Audit and fix the security issues**
6. **Redeploy proper rules**

## Additional Resources

- Firebase Security Rules Documentation: https://firebase.google.com/docs/database/security
- Firebase Rules Testing: https://firebase.google.com/docs/rules/unit-tests
- Security Best Practices: https://firebase.google.com/docs/rules/rules-and-auth
