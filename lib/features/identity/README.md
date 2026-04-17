# Identity System (Phase 1)

## Short Code Decisions

- Alphabet: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no `O/0/I/1/L`)
- Raw length: `6` chars (`~1B` combinations)
- Display format: `XXX-XXX` (example: `A4X-9K2`)

## Firestore Schema

`/users/{shortCode}`

- `uid: string`
- `fcmToken: string`
- `createdAt: timestamp`
- `lastSeen: timestamp`

## Provision Flow

1. Check Hive for existing `shortCode + uid`.
2. If missing, sign in with Firebase anonymous auth.
3. Generate a candidate short code.
4. Claim code using atomic Firestore transaction:
   - Read `/users/{candidate}`
   - If exists, regenerate
   - If absent, write record in the same transaction
5. Persist claimed `shortCode + uid` to Hive.
6. Return `AppUser`.

## Persistence Policy

- If app data is cleared or app is reinstalled, a new code is generated.
- Old code is intentionally orphaned.
- Inactive records are expected to expire after 30 days by backend cleanup policy.

This avoids recovery-flow complexity for an anonymous identity model.
