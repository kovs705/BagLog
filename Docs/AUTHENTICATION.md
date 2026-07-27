# Optional account authentication

BagLog remains local-first and fully usable without an account. Authentication
is an optional post-1.0 capability exposed from My Profile. Signing in alone
does not upload, merge, replace, or otherwise change local data. Private draft
sync additionally requires its DEBUG-only feature flag, a foreground app, a
valid BagLog session, and successful remote-profile preflight.

## Architecture

- `Services/Sources/Authentication` owns the authentication API adapter,
  Google SDK adapter, and Keychain session vault.
- `Services/Sources/Networking` owns the shared HTTPS client, same-origin
  redirect policy, and bounded response handling.
- `Services/Sources/Session` owns the one actor shared by authentication and
  synchronization.
- `BagLog/Application/Authentication` owns the `@MainActor @Observable` state machine and live/UI-test
  composition.
- The BagLog access/refresh pair is the authentication source of truth. A Google SDK session alone
  never marks the app signed in.
- API consumers request only a valid access token. The refresh token never
  enters sync engine state, transport request models, SwiftData, or UI state.
- Concurrent refresh requests await one shared refresh task. The controller
  refreshes shortly before expiry, saves the rotated pair atomically, and
  notifies `AuthenticationStore` when a rejected refresh invalidates the
  session.
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
- `BAGLOG_PRIVATE_SYNC_ENABLED`: checked in as `NO`; only exact `YES` enables
  private sync in DEBUG builds. Release builds always disable it.

The local file is ignored by Git. CI may inject the same build settings. The backend's
`BAGLOG_GOOGLE_CLIENT_ID` must exactly match `BAGLOG_GOOGLE_SERVER_CLIENT_ID`.

Without local or CI configuration, the app still launches and all guest workflows remain available;
attempting Google sign-in produces a safe configuration message.

## Security behavior

- Only a Google ID token is sent to `POST /v1/auth/google/sign-in`, over HTTPS.
- Authentication and sync endpoints require an HTTPS base URL and reject
  redirects to a different scheme, host, or port.
- Response bodies larger than 64 KiB are rejected before decoding.
- Tokens, authorization headers, provider profile fields, and raw response bodies are never logged or
  included in user-facing errors.
- Refresh replaces the stored pair only after a successful response and
  successful atomic Keychain save. If that save fails, the live rotated pair
  remains available for an explicit persistence retry.
- An authenticated sync request may force one refresh and retry once after
  `401`; a second rejection is surfaced and cannot loop.
- Logout clears Keychain and the local Google SDK session only after the backend confirms revocation.
  A failed logout keeps the signed-in state and exposes retry.

## Synchronization profile preflight

The sync engine calls `GET /v1/profile` before accessing private loadouts. If
the account has no remote profile and the device has a local profile, it calls
`POST /v1/profile` with that handle, display name, and bio. A handle conflict is
presented as an actionable setup failure. With no local profile, sync remains
idle and asks the person to complete the existing profile flow.

The returned remote profile UUID and local profile UUID form the durable sync
scope. Sign-out cancels active work but retains scoped local state. Signing in
as another account cannot process, rebind, or send the earlier account's
pending work.

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
6. Two authenticated devices editing the same private draft, conflict
   resolution in both directions, tombstone behavior, and account switching.

These checks require real development configuration and cannot be replaced by CI fakes.
