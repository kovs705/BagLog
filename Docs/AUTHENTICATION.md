# Optional account authentication

BagLog remains local-first and fully usable without an account. Authentication is an optional
post-1.0 capability exposed from My Profile. Signing in does not upload, merge, replace, or otherwise
change the local `UserProfile`, kits, or media.

## Architecture

- `Services/Sources/Authentication` owns the HTTPS API adapter, redirect policy, Google SDK adapter,
  and Keychain session vault.
- `BagLog/Application/Authentication` owns the `@MainActor @Observable` state machine and live/UI-test
  composition.
- The BagLog access/refresh pair is the authentication source of truth. A Google SDK session alone
  never marks the app signed in.
- The complete BagLog token pair is stored as one Keychain value using
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Updating that one value atomically replaces a
  rotated refresh credential. Persisting the short-lived access token as well as the refresh token
  lets a relaunch restore an unexpired session without an unnecessary network request; both values
  receive the same device-only Keychain protection.
- Authentication state is not stored in SwiftData or `UserDefaults`.

## Google SDK dependency decision

The repository owner approved Google Sign-In implementation by requesting the ready task on
2026-07-22. The official `google/GoogleSignIn-iOS` package is pinned exactly to `9.0.0`; the app uses
the `GoogleSignIn` and `GoogleSignInSwift` products. The resolved package graph is committed for
review and reproducibility.

Version 9.0.0 was selected because it is the version specified by Google's current integration
guide and it owns the OAuth flow, callback validation, provider credential storage, official SwiftUI
button, and privacy metadata. Its included privacy manifest declares no tracking, lists the data
categories the SDK may collect for app functionality/analytics, and declares UserDefaults access
with required-reason code `CA92.1`. App privacy answers must be reviewed against the final use of the
SDK before submission.

No Google client secret belongs in the app or repository.

## Local configuration

Copy `Configuration/BagLog.local.xcconfig.example` to
`Configuration/BagLog.local.xcconfig` and provide:

- `BAGLOG_API_BASE_URL`: the HTTPS BagLog API origin.
- `BAGLOG_GOOGLE_IOS_CLIENT_ID`: the iOS OAuth client for `com.CodingKovs.BagLog`.
- `BAGLOG_GOOGLE_SERVER_CLIENT_ID`: the Web OAuth client used as the backend audience.
- `BAGLOG_GOOGLE_REVERSED_CLIENT_ID`: the reversed iOS client ID used as the callback URL scheme.

The local file is ignored by Git. CI may inject the same build settings. The backend's
`BAGLOG_GOOGLE_CLIENT_ID` must exactly match `BAGLOG_GOOGLE_SERVER_CLIENT_ID`.

Without local or CI configuration, the app still launches and all guest workflows remain available;
attempting Google sign-in produces a safe configuration message.

## Security behavior

- Only a Google ID token is sent to `POST /v1/auth/google/sign-in`, over HTTPS.
- Authentication endpoints reject redirects to a different scheme, host, or port.
- Response bodies larger than 64 KiB are rejected before decoding.
- Tokens, authorization headers, provider profile fields, and raw response bodies are never logged or
  included in user-facing errors.
- Refresh replaces the stored pair only after a successful response.
- Logout clears Keychain and the local Google SDK session only after the backend confirms revocation.
  A failed logout keeps the signed-in state and exposes retry.

## Release blockers

Google sign-in must not ship as BagLog's only third-party login unless an App Review Guideline 4.8
exception is confirmed. Sign in with Apple (or an equivalent compliant option) is required before a
production release. If account creation is enabled, an in-app account deletion flow is also required.
Neither blocker is implemented by this slice.

## Manual development verification

With development OAuth clients, callback scheme, signed build, and backend configured, verify:

1. Successful sign-in and backend exchange.
2. User cancellation returning silently to signed out.
3. Relaunch with a valid access token and relaunch requiring refresh rotation.
4. Offline and timeout messaging.
5. Backend logout followed by local Google sign-out.

These checks require real development configuration and cannot be replaced by CI fakes.
