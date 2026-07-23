# Task: Add Sign in with Google to BagLog

**Status:** Ready after dependency and OAuth configuration approval  
**Target release:** Post-1.0 / Milestone 1  
**Primary surface:** My Profile tab  
**Backend dependency:** Available in BagLogBackend (`POST /v1/auth/google/sign-in`)

## Goal

Add a production-quality Google sign-in vertical slice to the iOS app. A signed-out user can start Google authentication from My Profile, exchange the returned Google ID token for a BagLog session, restore that session after relaunch, and sign out.

The app must remain fully usable without an account. This task must not gate launch, local kits, local profiles, or any existing Release 1.0 workflow behind authentication.

## Important release constraints

- A paid Google developer account is **not required**. Google Cloud projects, OAuth clients, and Sign in with Google testing are available without a paid developer membership. Billing is not required for this basic OpenID Connect use case.
- A paid Apple Developer Program membership is not required to implement most of this task or run it in the simulator. Testing on a physical device still requires normal Apple code signing; a free Personal Team can be sufficient for development, subject to Apple's provisioning limitations.
- Do not ship Google as the only third-party login for the app's primary account. Under [App Review Guideline 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services), an equivalent privacy-preserving login option—normally Sign in with Apple—is required unless BagLog qualifies for a listed exception.
- If account creation is enabled in the submitted app, an in-app account deletion flow is also required. Google sign-in may be developed and merged before those flows exist, but **Sign in with Apple/equivalent login and account deletion are production-release blockers**.

## Current context

- BagLog 1.0 is local-first and intentionally has no account requirement.
- `ProfileView` is currently a placeholder, making the My Profile tab the correct entry point.
- The app uses lightweight `@MainActor @Observable` feature stores with explicit protocol dependencies. Keep that architecture; do not introduce MVVM, TCA, or a second navigation system for this feature.
- The backend accepts a Google ID token, verifies it server-side, and returns a BagLog access/refresh token pair.
- Google identity must be keyed by the verified `sub` claim. Never link or merge accounts by email address.
- Existing local `UserProfile`, kits, media, and SwiftData records must remain unchanged. Account-to-local-data synchronization is a separate task.

## Approval gate

Before implementation, obtain repository-owner approval to add the official [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) package, pinned to an exact reviewed version. At task preparation time, Google's integration guide specifies version `9.0.0` and the `GoogleSignIn` and `GoogleSignInSwift` products.

This dependency is justified because it owns Google's OAuth flow, callback validation, provider session restoration, branding-compliant SwiftUI button, and privacy metadata. Do not build a custom OAuth flow or reproduce Google's logo/button while this approval is pending. Record the dependency decision in the project's architecture/decision documentation when it is accepted.

## OAuth configuration

Create one Google Cloud project or use the BagLog project, configure an External OAuth consent screen in testing mode, and request only the default OpenID Connect scopes needed for authentication.

Create both OAuth clients:

1. **iOS client** for bundle identifier `com.CodingKovs.BagLog`.
2. **Web application client** used as the server audience.

Configure the app with:

- `GIDClientID`: iOS OAuth client ID.
- `GIDServerClientID`: Web OAuth client ID.
- URL scheme: the reversed iOS client ID from the downloaded Google configuration.
- `BAGLOG_API_BASE_URL`: environment-specific BagLog API origin.

Configure the backend's `BAGLOG_GOOGLE_CLIENT_ID` with the **same Web client ID** used by `GIDServerClientID`.

Client IDs and API origins are configuration, not secrets, but do not commit personal or production-specific values directly into `Project.swift`. Add checked-in example configuration and inject real per-environment values from an ignored local configuration or CI. Never add a Google client secret to the iOS app.

## User experience

### Signed out

- Keep the existing My Profile tab accessible.
- Show a short explanation that authentication creates or opens a BagLog account. Do not promise synchronization in this task.
- Render the official `GoogleSignInSwift.GoogleSignInButton` using its supported light/dark appearance and standard branding.
- Give the control the accessibility identifier `google-sign-in-button`.
- Disable repeated activation and show progress while either Google authentication or the backend exchange is in flight.
- Treat user cancellation as a normal return to the signed-out state; do not show an error alert.
- Show concise, retryable messages for network, provider, rate-limit, and server failures. Do not expose raw server responses or token-validation details.

### Signed in

- Show a neutral `Signed in with Google` state. The current backend response does not contain a BagLog profile, so do not use provider email or display name as durable BagLog profile data.
- Keep local-only content visible and editable exactly as before.
- Provide a Sign Out action.
- Sign Out calls `POST /v1/auth/logout` first. Clear the local BagLog session and call the Google SDK's local sign-out only after confirmed server revocation.
- If logout fails, retain the session and show a retryable error so the UI does not falsely claim that the refresh token was revoked.

### Session restoration

- Restore the BagLog session during app composition without blocking access to local content.
- If the access token is usable, enter the signed-in state.
- If it is expired and the refresh token is valid, call `POST /v1/auth/refresh` and atomically save the rotated token pair.
- If refresh is rejected, clear the BagLog session and return to signed out.
- The BagLog session is the app's authentication source of truth. A restored Google SDK session alone must not be treated as a valid BagLog session.

## Backend contract

### Sign in

`POST /v1/auth/google/sign-in`

```json
{
  "identity_token": "<Google ID token>"
}
```

On success, decode and store the BagLog token pair:

```json
{
  "access_token": "...",
  "access_expires_at": "...",
  "refresh_token": "...",
  "refresh_expires_at": "...",
  "token_type": "Bearer"
}
```

Handle stable API responses for `400`, `401`, `429`, and `503`. The client must obtain `user.idToken.tokenString` from the Google SDK and send it only over HTTPS. Never send the Google user ID as authentication proof.

### Refresh

`POST /v1/auth/refresh`

```json
{
  "refresh_token": "<current BagLog refresh token>"
}
```

The endpoint rotates the refresh token. Replace the stored pair atomically; never keep using the old refresh token after a successful response.

### Logout

`POST /v1/auth/logout` with `Authorization: Bearer <BagLog access token>`; expect `204 No Content`.

## Proposed implementation shape

Use the existing composition-root and feature-store conventions. Names can change during implementation, but retain these boundaries:

```text
Services/Sources/Authentication/
  AuthenticationAPI.swift        URLSession adapter for sign-in/refresh/logout
  AuthenticationModels.swift     API DTOs and stable domain errors
  GoogleIdentityProvider.swift   Thin adapter over GoogleSignIn
  SessionVault.swift             Keychain-backed BagLog token storage

BagLog/Application/Authentication/
  AuthenticationDependencies.swift
  AuthenticationStore.swift      @MainActor @Observable state machine

BagLog/Application/Profile/
  ProfileView.swift              Signed-out, busy, error, and signed-in UI

BagLogTests/Authentication/
  AuthenticationStoreTests.swift
  AuthenticationAPITests.swift
```

Implementation requirements:

- Define protocols for Google identity, BagLog authentication API, clock, and session storage so tests do not open Google's UI or use the real Keychain/network.
- Model authentication as explicit states such as restoring, signed out, signing in, and signed in. Avoid unrelated Boolean flags that can produce impossible UI states.
- Keep the `AuthenticationStore` on `@MainActor`; make blocking/network storage adapters concurrency-safe and pass cancellation through async work.
- The Google SDK requires a UIKit presentation context. Isolate any `UIViewControllerRepresentable` or presenter lookup in one small bridge; UIKit is not permitted elsewhere in the feature.
- Use an `actor` or otherwise `Sendable` API client. Do not use callbacks, `DispatchQueue`, or detached tasks.
- Inject the store once from `BagLogApp`/the composition root so Profile does not construct live services.
- Preserve the existing `--ui-testing` dependency-injection path and provide deterministic fake auth outcomes for UI tests.

## Security and privacy requirements

- Treat the Google ID token and all BagLog tokens as secrets. Never log them, include them in errors, attach them to analytics, or expose them to crash breadcrumbs.
- Do not persist a copied Google ID token, Google access token, email, or profile payload. Let the Google SDK manage its own provider session.
- Store BagLog credentials in Keychain with a device-only accessibility class; never use `UserDefaults`, SwiftData, plist files, or source-controlled configuration.
- Prefer keeping the access token in memory and persisting only the refresh credential plus required expiry metadata. If both are persisted for a justified reason, both must use Keychain.
- Make refresh-token replacement atomic so a crash cannot restore a superseded credential.
- Send authentication requests only to the configured HTTPS API origin. Do not add a broad App Transport Security exception.
- Reject cross-origin redirects for authentication endpoints so credentials cannot be forwarded to another host.
- Cap accepted authentication response bodies at 64 KiB before decoding.
- Do not place sensitive request/response values in localized user-facing errors.
- Do not infer account linkage from email. Apple and Google identities remain separate until an explicit, authenticated account-linking design is approved.
- Review the package's privacy manifest and resolved version during dependency review and commit the lockfile change.

## Acceptance criteria

- [ ] The app still launches and all local Release 1.0 functionality works without signing in or having network access.
- [ ] My Profile shows the official Google button in signed-out state with correct branding in light and dark appearances.
- [ ] Rapid repeated taps start only one authentication attempt.
- [ ] Cancelling Google's sheet returns silently to signed out.
- [ ] A missing Google ID token fails locally and does not call the backend.
- [ ] A valid Google ID token is exchanged using the documented endpoint and request shape.
- [ ] Successful authentication stores the BagLog session in Keychain and updates the UI to `Signed in with Google`.
- [ ] Relaunch restores or refreshes the BagLog session without hiding or delaying local content.
- [ ] Refresh rotation replaces the old credential atomically.
- [ ] Invalid/revoked refresh credentials clear the local session and return to signed out.
- [ ] Sign Out revokes the backend session before clearing local credentials.
- [ ] `400`, `401`, `429`, `503`, offline, timeout, malformed JSON, oversized response, and cancellation paths have safe deterministic behavior.
- [ ] Authentication requests reject redirects to a different origin.
- [ ] No token, authorization header, email, private profile value, or API response body is logged.
- [ ] Existing local `UserProfile`, kits, and media are neither overwritten nor uploaded.
- [ ] VoiceOver identifies the sign-in and sign-out controls; Dynamic Type does not clip the surrounding content.
- [ ] Unit and UI tests use fakes and never require a live Google account in CI.
- [ ] A manual development test covers successful sign-in, cancel, relaunch, refresh, offline failure, and logout against the development backend.
- [ ] Documentation states that Sign in with Apple/equivalent login and in-app account deletion block App Store release.

## Tests

Add Swift Testing coverage for:

- successful Google credential exchange;
- cancellation and missing-ID-token handling;
- duplicate-tap suppression;
- each mapped backend error;
- session restore with valid access token;
- expired access token with successful refresh rotation;
- rejected refresh clearing the session;
- logout success and logout failure;
- task cancellation during provider and backend work;
- token redaction from errors/descriptions;
- request method, path, headers, body, response-size limit, and redirect policy.

Add a focused UI test using launch arguments or injected fakes to verify the signed-out, loading, signed-in, and retry states. Do not automate Google's real consent UI in CI.

Before handoff:

```sh
tuist generate --no-open
xcodebuild -workspace BagLog.xcworkspace \
  -scheme BagLog \
  -destination 'platform=iOS Simulator,name=<available iOS 26 simulator>' \
  test
```

Also perform the manual Google flow on at least one signed build because the callback URL scheme, Keychain access, OAuth bundle identifier, and presentation context cannot be fully validated by fakes.

## Out of scope

- Sign in with Apple implementation.
- In-app account deletion UI.
- Linking Google and Apple identities.
- Email-based account matching.
- Cross Account Protection events.
- Google API scopes beyond basic authentication.
- Cloud synchronization or upload of existing local data.
- Remote profile editing or replacing the local `UserProfile` model.
- Backend endpoint changes.
- A redesign of the full Profile experience.

## Definition of done

This task is complete when the Google button and BagLog session lifecycle work behind the Profile tab, all automated and manual checks above pass, the app remains usable as a guest, and no release-blocking requirement is misrepresented as complete.

The feature is eligible for production release only after Sign in with Apple (or a confirmed Guideline 4.8 exception) and in-app account deletion are also complete.

## References

- [Google: Start integrating Sign in with Google into an iOS app](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Google: Authenticate with a backend server](https://developers.google.com/identity/sign-in/ios/backend-auth)
- [GoogleSignInSwift button reference](https://developers.google.com/identity/sign-in/ios/reference-swift/Structs/GoogleSignInButton)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- BagLog backend development setup: `BagLogBackend/docs/development.md`
- BagLog backend authentication ADR: `BagLogBackend/docs/decisions/0005-account-authentication-and-deletion.md`
