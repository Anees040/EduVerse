/**
 * Migration script: migrate chat_history -> chat_sessions + chat_messages
 *
 * Usage:
 *   # dry-run (no writes)
 *   node migrate_chat_history.js --dry-run
 *
 *   # apply (perform writes). Ensure GOOGLE_APPLICATION_CREDENTIALS points to service account
 *   node migrate_chat_history.js --apply
 *
 * Behavior:
 * - For each user under /chat_history/{uid}, create a single legacy session: chat_sessions/legacy-{uid}
 *   if it does not already exist.
 * - Copy all messages from chat_history/{uid}/{chatId}/messages into chat_messages/legacy-{uid}/{msgId}
 *   preserving timestamps and original message ids.
 * - Add student/{uid}/chatIds/{legacyChatId}: true or teacher/{uid}/chatIds/{legacyChatId}: true
 *   depending on which node exists for the uid.
 * - Does NOT delete or modify /chat_history. Idempotent: re-running will skip users that already have
 *   chat_sessions/legacy-{uid} present.
 */

const admin = require('firebase-admin');
const argv = require('minimist')(process.argv.slice(2));
const dryRun = !!argv['dry-run'] && !argv['apply'];
const apply = !!argv['apply'];

if (!dryRun && !apply) {
  console.log('Usage: node migrate_chat_history.js --dry-run OR --apply');
  process.exit(1);
}

(async () => {
  try {
    admin.initializeApp();
    const db = admin.database();

    const chatHistorySnap = await db.ref('chat_history').get();
    if (!chatHistorySnap.exists()) {
      console.log('No chat_history node found. Nothing to do.');
      return;
    }

    const users = chatHistorySnap.val();
    const userIds = Object.keys(users || {});
    console.log(`Found ${userIds.length} users with legacy chat_history.`);

    for (const uid of userIds) {
      const legacyChatId = `legacy-${uid}`;

      const sessionRef = db.ref(`chat_sessions/${legacyChatId}`);
      const sessionSnap = await sessionRef.get();
      if (sessionSnap.exists()) {
        console.log(`Skipping ${uid} - legacy session already exists (${legacyChatId}).`);
        continue;
      }

      // Determine owner role by checking existence under student/uid or teacher/uid
      let ownerRole = null;
      const studentSnap = await db.ref(`student/${uid}`).get();
      if (studentSnap.exists()) ownerRole = 'student';
      const teacherSnap = await db.ref(`teacher/${uid}`).get();
      if (teacherSnap.exists()) ownerRole = 'teacher';

      if (!ownerRole) {
        console.log(`Skipping ${uid} - no student/teacher node found for UID. Please verify manually.`);
        continue;
      }

      const userChats = users[uid] || {};

      // collect all messages across all chat ids for this user (preserve ordering by timestamp)
      const allMessages = [];
      for (const chatId of Object.keys(userChats)) {
        const chatObj = userChats[chatId] || {};
        const msgs = chatObj['messages'] || {};
        for (const msgId of Object.keys(msgs)) {
          const m = msgs[msgId];
          // try to map sender -> role
          const sender = (m['sender'] || '').toString();
          const role = sender.toLowerCase() === 'user' ? 'user' : 'assistant';
          const timestamp = m['timestamp'] || Date.now();
          const content = m['text'] || '';
          allMessages.push({ msgId, role, timestamp, content });
        }
      }

      if (allMessages.length === 0) {
        console.log(`No messages for ${uid}, creating empty legacy session ${legacyChatId}.`);
      }

      // sort by timestamp ascending
      allMessages.sort((a, b) => (a.timestamp || 0) - (b.timestamp || 0));

      // Determine createdAt and updatedAt
      const createdAt = allMessages.length ? allMessages[0].timestamp : Date.now();
      const updatedAt = allMessages.length ? allMessages[allMessages.length - 1].timestamp : Date.now();

      console.log(`Preparing legacy session ${legacyChatId} for user ${uid} with ${allMessages.length} messages.`);

      if (dryRun) {
        console.log(`[dry-run] Would create session chat_sessions/${legacyChatId}`);
        console.log(`[dry-run] Would set ${ownerRole}/${uid}/chatIds/${legacyChatId}: true`);
        console.log(`[dry-run] Would write ${allMessages.length} messages to chat_messages/${legacyChatId}`);
        continue;
      }

      if (apply) {
        // create session
        await sessionRef.set({
          ownerId: uid,
          ownerRole: ownerRole,
          title: 'Legacy Chat',
          createdAt: createdAt,
          updatedAt: updatedAt,
        });

        // set owner ref
        await db.ref(`${ownerRole}/${uid}/chatIds/${legacyChatId}`).set(true);

        // write messages under chat_messages/{legacyChatId}/{msgId}
        const batchRef = db.ref(`chat_messages/${legacyChatId}`);
        const updates = {};
        for (const m of allMessages) {
          // reuse original msgId to preserve ordering (push keys are time-ordered)
          updates[m.msgId] = {
            role: m.role,
            content: m.content,
            timestamp: m.timestamp,
          };
        }
        if (Object.keys(updates).length) {
          await batchRef.update(updates);
        }

        console.log(`Applied migration for ${uid} => ${legacyChatId} (${allMessages.length} messages).`);
      }
    }

    console.log('Migration finished. chat_history has NOT been deleted. Verify data and delete only when ready.');
  } catch (err) {
    console.error('Migration error:', err);
    process.exit(1);
  }
})();
