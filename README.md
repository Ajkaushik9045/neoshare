NeoShare — Flutter Developer Intern Assessment Submission

NeoShare is a real-time cross-device file sharing Android app built with Flutter. Two users exchange files over the internet using short human-readable codes — no accounts, no email, no phone number required.


How to Run Locally

Prerequisites

Flutter 3.x stable, Dart 3.11 or above
Android Studio with Android SDK, API 21 minimum
Node.js 18 or above (only needed if deploying Cloud Functions)
Firebase CLI — install with: npm install -g firebase-tools

Steps

Clone the repository and install Flutter dependencies:

    git clone <repo-url>
    cd neoshare
    flutter pub get

The firebase_options.dart and android/app/google-services.json files are included in the repository. The app runs against a live Firebase project (neoshare-e2fa7) immediately — no additional Firebase setup is needed to run and test.

Connect a physical Android device and run:

    flutter run

To deploy the backend yourself (optional):

    cd functions
    npm install
    firebase deploy --only functions,firestore:rules,firestore:indexes


Devices Tested On

Samsung Galaxy Note 20 Ultra (SM-N986B), Android 13, API 33 — primary test device
Samsung Galaxy S21, Android 13, API 33 — secondary device for two-device transfer testing


Architecture

NeoShare follows Clean Architecture with BLoC as the state management pattern. The codebase is divided into three strict layers. The presentation layer never talks directly to data sources, and the domain layer has no Flutter or Firebase imports.

Presentation Layer
Flutter widgets and BLoC state machines. SendBloc drives the upload flow. InboxBloc drives the receive flow. IdentityBloc handles provisioning. No business logic lives here.

Domain Layer
Pure Dart entities (Transfer, TransferFile, AppUser), abstract repository interfaces, and use cases. This layer has zero dependencies on Flutter or Firebase.

Data Layer
Concrete repository implementations backed by Firestore, Firebase Storage, and Hive for local persistence. This is the only layer that knows about Firebase.

Transport flow:

    Device A (Sender)                        Device B (Recipient)
    SendBloc                                 InboxBloc
        |                                        |
        |  1. Write transfer document            |
        |-----------> Firestore <----------------|  (real-time listener)
        |                                        |
        |  2. Upload file bytes                  |
        |-----------> Firebase Storage           |
        |                                        |
        |  3. Cloud Function fires on complete   |
        |             FCM Push ----------------->|  (notification)
        |                                        |
        |                    Firebase Storage <--|  4. Download


Folder Structure

    lib/
    |-- core/
    |   |-- constants/        app-wide constants, short-code alphabet
    |   |-- di/               GetIt service locator, dependency wiring
    |   |-- notifications/    FCM service, notification permission service
    |   |-- permissions/      storage permission service and UI helper
    |   |-- platform/         Pigeon-generated platform channel bridges
    |   |-- routing/          GoRouter navigation configuration
    |   `-- utils/            logger, crypto util, battery monitor
    |
    `-- features/
        |-- identity/
        |   |-- data/         Firestore and Hive data sources
        |   |-- domain/       AppUser entity, IdentityRepo interface
        |   `-- presentation/ IdentityBloc, OnboardingPage
        |
        `-- transfer/
            |-- data/         Firestore, Storage, local data sources
            |-- domain/       Transfer and TransferFile entities, repo interface
            `-- presentation/ SendBloc, InboxBloc, SendPage, InboxPage

    android/app/src/main/kotlin/
    |-- MainActivity.kt                 Pigeon host, lifecycle MethodChannel
    `-- TransferForegroundService.kt    background upload foreground service

    pigeons/                            Pigeon contract definitions
    functions/                          Firebase Cloud Functions (Node.js)


What Was Built

Core flow working end to end on two physical Android devices:

Anonymous identity provisioning using Firebase anonymous auth. Each device gets a 6-character short code on first launch, stored locally in Hive. No login required.

Short-code based sending. Sender types recipient's code, picks files via native file picker, and sends. Recipient sees the transfer arrive in real time via Firestore listener.

Real-time progress on both sides. Sender sees per-file and aggregate upload progress. Recipient sees download progress per file.

FCM push notification to recipient when transfer completes, with deep link that opens the receive tab regardless of whether the app is open, backgrounded, or terminated.

Files saved to Android Downloads via MediaStore. Recipient taps Save and the file appears in the system Downloads app.


Platform Channel Bonus — Pigeon

All native integrations were implemented via Pigeon (type-safe code generation), not pub.dev packages.

1. Native File Picker
FileHostApi.pickFiles() invokes ACTION_GET_CONTENT directly in Kotlin. Files are copied to the app cache directory and the absolute path is returned to Dart. This avoids SAF URI issues on Android 10 and above.

2. Save to Downloads via MediaStore
FileHostApi.saveToDownloads() writes received files to MediaStore.Downloads using the Android 10 scoped storage API. Files appear in the system Downloads app immediately after saving.

3. Background Transfer — Foreground Service
TransferForegroundService is a Kotlin Service with stopWithTask set to false. When the user swipes the app from recents, the service survives and switches the notification to a paused state with a tap-to-resume action. On reopen, SendBloc reads the persisted transferId from Hive, checks Firestore for the transfer status, and shows a resume prompt. Firebase Storage resumable uploads pick up from the last uploaded byte.

Known limitation: tapping the paused notification opens the app correctly but the upload does not auto-resume — the user must tap Send Files again. The resume detection works but re-triggering the upload automatically requires the original file paths which are lost when the process is killed. This is documented honestly below.

4. SDK Version Channel
A lightweight MethodChannel exposes Build.VERSION.SDK_INT to Dart. This is used to gate storage permission requests — WRITE_EXTERNAL_STORAGE is only requested on Android 9 and below. On Android 10 and above MediaStore handles writes without any permission.

What I would do with more time: implement the Nearby transport bonus using Wi-Fi Direct or BLE for peer-to-peer transfer when devices are physically close, falling back to Firebase when they are not.


Edge Cases

Identity and Addressing

Short-code collisions (required)
Handled. Code generation uses a 32-character safe alphabet. Registration uses an atomic Firestore transaction that only writes if the document does not already exist. On collision the app retries up to 10 times with a new candidate code before surfacing an error.

Invalid recipient code (required)
Handled. Before any upload begins, the app queries Firestore for the recipient's document. If it does not exist, the user sees a clear message: "User not found. Please check the short code and try again." No upload is attempted.

Ambiguous characters
Handled. The alphabet is ABCDEFGHJKLMNPQRSTUVWXYZ23456789. The characters O, 0, I, l, and 1 are intentionally excluded to prevent visual confusion.

Self-send
Handled. Blocked. If the sender types their own code, the app shows "You cannot send files to yourself" before any network call is made.

Identity persistence
Handled with a documented tradeoff. The short code is cached in Hive on the device. If the user clears app data or reinstalls, the local cache is gone and a new code is provisioned. The old code remains in Firestore but is no longer associated with the device. There is no recovery flow — this is an intentional tradeoff for simplicity. A recovery mechanism would require linking the code to a persistent identifier such as a phone number, which conflicts with the anonymous requirement.


Transport and Delivery

Recipient offline (required)
Handled. The transfer document is written to Firestore with a 48-hour TTL (expiresAt field). The upload proceeds regardless of whether the recipient is online. When the upload completes, a Cloud Function sends an FCM push notification to the recipient. FCM queues the notification for up to 4 weeks if the device is offline. A scheduled Cloud Function runs every 6 hours to mark expired transfers and delete their Storage files.

Network drops mid-transfer (required)
Handled. Firebase Storage putFile creates a resumable upload session server-side. On the Dart side, the upload loop retries up to 300 times with a 5-second delay between attempts, catching transient errors including network loss, timeout, and cancellation. The upload resumes from the last uploaded byte on reconnect.

Sender kills the app mid-upload
Partially handled. The transferId is persisted to Hive before the upload starts. The Android foreground service survives task removal (stopWithTask="false") and shows a paused notification. On reopen, the app detects the in-progress transfer from Firestore and shows a resume prompt. The limitation is that the original file paths from the Pigeon-staged cache are gone after process death, so the user must re-select files to complete the transfer. The transfer document and already-uploaded bytes are preserved.

Duplicate delivery
Handled. The receiver deduplicates by transferId using Hive. A transfer that has already been fully processed is skipped on subsequent Firestore listener updates.

Metered connections
Handled. Before starting an upload, the app checks connectivity type. If the connection is metered (mobile data) and the total file size exceeds 10 MB, a confirmation dialog is shown. The upload only proceeds if the user confirms.


Files and Media

Large files (required)
Handled. The ceiling is 500 MB per file, enforced in the BLoC before any upload begins. Firebase Storage putFile streams the file in chunks — the file is never loaded into memory. Downloads also stream to a temp file via writeToFile.

Multiple files at once (required)
Handled. All files in a transfer upload concurrently using Future.wait with isolated error handling. Each file's future resolves to either null (success) or the error object (failure) — it never throws. If some files succeed and some fail, the transfer is still marked complete for the successful files. Only if every single file fails is the transfer marked as failed.

Unusual MIME types
Handled. The app uses a three-tier resolution: system-provided MIME type first, then the mime package for extension-based lookup (handles .heic, .webp, .mov, and others), then application/octet-stream as a final fallback. The app never crashes on an unknown type.

Empty or zero-byte files
Handled. Files with sizeBytes equal to zero are rejected before upload with a clear message naming the specific file.

Filename conflicts on save
Delegated to MediaStore. Android 10 and above auto-renames duplicates (for example photo (1).jpg). There is no explicit prompt or override in the app.

Corrupted transfers
Handled. SHA-256 is computed on the sender side and stored in the Firestore transfer document per file. On the recipient side, after the download completes and before the file is saved to Downloads, the hash of the downloaded temp file is computed and compared. If they do not match, the file is marked as corrupted in Firestore and the temp file is deleted. The user sees the corrupted state in the inbox.


Permissions and Platform

Permission denial (required)
Handled. Notification permission: if denied, a non-blocking banner is shown explaining that upload progress notifications will not appear. If permanently denied, a banner with an Open Settings button is shown.

Scoped storage (Android 10 and above)
Handled. All file writes go through MediaStore via the Pigeon saveToDownloads channel. No arbitrary file paths are used. The app never requests WRITE_EXTERNAL_STORAGE on Android 10 and above.

OEM battery killers
Acknowledged, not fully solved. The Android foreground service with startForeground and START_STICKY provides the strongest available protection against OEM process killing. On Samsung, Xiaomi, and OnePlus devices with aggressive battery optimisation, the service may still be killed. Users on these devices may need to whitelist NeoShare in battery settings. This is a known limitation of the Android platform that cannot be fully solved at the app level.

App killed by OS under memory pressure
Handled. The active transferId is persisted to Hive before the upload starts and cleared on completion or failure. On next launch, the app reads the persisted transferId, checks Firestore for the transfer status, and shows a resume prompt if the transfer is still in progress.


Mobile Device Conditions

Incoming transfer while app is closed (required)
Handled. When a transfer completes, a Firebase Cloud Function sends an FCM push notification to the recipient. The notification contains a data payload with action: open_receive and a deep link. Tapping the notification opens the app and navigates to the receive tab in all three states: foreground, background, and terminated. The terminated state is handled by capturing getInitialMessage before runApp and navigating post-frame after the router is mounted.

Low device storage
Handled. Before starting any download, the app calls getFreeSpace via the Pigeon channel and compares it against the total size of files to download. If there is not enough space, the download is rejected with a clear message stating how much space is needed and how much is available.

Low battery and power-save mode
Handled. BatteryMonitor uses the battery_plus plugin to watch battery state changes. A warning banner is shown at the top of the send page when the battery level is at or below 15 percent or when the device is in battery saver mode. The upload is not blocked — the banner is informational.

Network transitions (Wi-Fi to cellular mid-transfer)
Handled by Firebase Storage internally. The resumable upload session survives network type changes. The retry loop on the Dart side catches any transient errors during the transition and resumes automatically.

Airplane mode toggled mid-transfer
Handled by the retry loop. Airplane mode causes a network error which is caught as a transient error. The loop retries with a 5-second delay. When airplane mode is turned off and connectivity is restored, the upload resumes from the last uploaded byte. Not handled specificallt.

App backgrounded long then foregrounded
Handled. The onResume lifecycle event in MainActivity sends a signal to Dart via a MethodChannel. SendBloc receives this signal, reads the persisted transferId from Hive, and checks Firestore for the current transfer status. If the transfer is still in progress, the paused UI is shown.


Security and Privacy

Transport encryption (required)
Handled. All Firebase SDK connections use TLS 1.2 or above. The AndroidManifest sets android:usesCleartextTraffic="false" and references a network_security_config.xml that sets cleartextTrafficPermitted to false. Plain HTTP connections are blocked at the OS level.

Content privacy
Partially handled. Rate limiting is implemented via a Cloud Function that counts transfers per sender in the last hour and deletes the transfer document if the limit of 10 per hour is exceeded. The sender receives a clear error message. An accept/reject prompt and block list were scoped out of this submission.

At-rest encryption
Firebase Storage encrypts all data at rest using Google-managed AES-256 keys by default. There is no additional app-level encryption layer.

Short-code guessability
Handled. The alphabet has 32 characters and codes are 6 characters long, giving approximately 1 billion possible combinations (32 to the power of 6). Firestore Security Rules prevent unauthenticated enumeration. The probability of guessing a valid code at random is negligible.


UX Under Failure

Every error in the app surfaces a message the user can act on. There are no raw exception strings shown to the user. The _friendlyMessage and _friendlyUploadError helpers in SendBloc map all known error conditions to plain-language messages.

In-progress transfer state survives backgrounding and process death via Hive persistence as described above.

Known gap: there is no cancel button on an in-progress upload. Once started, the upload runs until completion, failure, or the user force-quits the app. This is a UX gap that would be addressed in the next iteration.


Known Bugs and Limitations

iOS is not implemented. The Dart-side architecture is platform-agnostic but the Pigeon native implementations (file picker, MediaStore, foreground service) are Kotlin-only. Shipping Android properly was prioritised over half-shipping both platforms.

Upload does not auto-resume after process death. The resume prompt appears correctly but the user must tap Send Files again and re-select files. The original Pigeon-staged file paths are lost when the process is killed. Solving this properly requires either keeping the upload in a native Kotlin coroutine that survives process death, or using a background isolate.

No cancel affordance on uploads. The retry loop runs up to 300 times. A cancel mechanism would require propagating a cancellation token through the upload stream, which was not implemented.

Filename conflicts are handled by MediaStore auto-rename, not by the app. There is no user prompt.( auto handeled by file(1), file(2))


Transport Choice Rationale

Firebase was chosen over WebSockets, WebRTC, or Supabase for the following reasons.

Firestore real-time listeners provide sub-second delivery when the recipient is online without any WebSocket infrastructure to manage. The listener is a single line of code and handles reconnection automatically.

Firebase Storage resumable uploads solve the network-drop problem natively. There is no custom chunking code. The SDK handles session management, retry, and resumption transparently.

FCM handles the offline notification case with platform-native delivery and queuing.

Firebase anonymous auth gives each device a stable UID without any user friction.

The tradeoff is vendor lock-in and Firebase Storage costs at scale. For an MVP focused on correctness and reliability, this was the right choice. It allowed full focus on product behaviour rather than infrastructure.


AI Tool Usage

This project was built using Kiro, a Claude-based AI IDE, as the primary coding assistant and claude for planning and structuring understanding the need 

Where AI was used: scaffolding the clean architecture structure and BLoC boilerplate, generating Pigeon contract files and the Kotlin foreground service, writing Cloud Functions for rate limiting, FCM notification, and expiry cleanup, implementing permission handling flows, and writing unit tests for BatteryMonitor and NotificationPermissionService.

Where I overrode AI suggestions:

AI suggested device_info_plus for SDK version detection. I replaced it with a lightweight MethodChannel to avoid a MissingPluginException that occurs on hot restart when the plugin's native channel is not re-registered.

AI used Future.wait which propagates the first failure and cancels remaining uploads. I changed it to isolated error handling using .then and .onError so one file failure does not kill the batch.

AI placed onTaskRemoved in MainActivity. This is incorrect — onTaskRemoved is a Service method, not an Activity method. I caught this and moved it to TransferForegroundService.

AI added orderBy('createdAt') to the Firestore query alongside a not-equal filter on status. This combination requires a composite index. I moved the sort client-side to eliminate the index requirement and avoid a runtime crash on first launch.

The senderId and senderCode fields were hardcoded as placeholder strings in the AI-generated upload flow. I caught this during the final audit and wired them to the actual identity from LocalIdentityDataSource.

Every architectural decision was reviewed. AI accelerated implementation significantly but the final code reflects deliberate choices, not unreviewed generation.
