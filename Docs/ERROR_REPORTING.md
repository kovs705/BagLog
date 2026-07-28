# Error reporting

BagLog uses Sentry Cocoa for iOS crash and handled-error reporting. The
integration intentionally disables performance tracing, replay, logs, metrics,
network breadcrumbs, screenshots, and view hierarchy capture.

## Runtime configuration

Set `BAGLOG_SENTRY_DSN` in the ignored
`Configuration/BagLog.local.xcconfig` file for local development, and inject
the same build setting in CI. The checked-in default is blank, so builds
without a DSN do not send telemetry.

The app starts Sentry before composing persistence and authentication. To
report a handled failure without sending the error's potentially sensitive
description, call:

```swift
BagLogErrorReporting.capture(
    error: error,
    operation: "feature.operation"
)
```

Use a stable, non-sensitive operation name. Never attach tokens, user
identifiers, loadout content, media metadata, or request URLs.

## Debug-symbol upload

`Project.swift` owns a Release-only post-build phase that uploads dSYMs to the
`squiddy-labs/baglog-ios` Sentry project. It requires `sentry-cli` and reads
`SENTRY_AUTH_TOKEN` from the build environment. The token must be an
organization token with debug-file upload access and must live in CI secret
storage, never in source control or an xcconfig file.

The build warns and skips upload when the token is absent. If a configured
upload fails, the Release build fails so an unsymbolicated build is not shipped
silently.

## Verification

For a Debug-only smoke test, launch the app once with:

```text
--sentry-verification
```

The app sends a sanitized error-level event and flushes it before continuing.
Remove the launch argument after verifying the event in Sentry.

The Sentry project keeps the default server-side data scrubbers enabled and
prevents IP addresses from being stored for new events. Its high-priority issue
alert sends email notifications.
