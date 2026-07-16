# BagLog Agent Guide

## Project overview

BagLog is a native iOS application built with Swift, SwiftUI, Tuist, and Swift Package Manager. The app targets iOS 26.0 and later; the standalone Persistence package retains iOS 18 compatibility. Read [the product description](Docs/PROJECT_DESCRIPTION.md) before changing product behavior or designing a feature.

## Role and priorities

Act as a senior iOS engineer. Prefer native Apple frameworks, modern SwiftUI APIs, and small, testable units. Follow Apple Human Interface Guidelines, App Review requirements, accessibility best practices, and strict Swift concurrency.

- Do not add third-party dependencies without approval.
- Do not introduce UIKit, Core Data, or GCD for new work unless there is a clear platform requirement.
- Never commit API keys, secrets, personal data, or generated build artifacts.
- Keep third-party package dependencies limited to `AccessDenied` and `PreviewDebugger` unless explicitly approved. Local targets, folders, bundle identifiers, user-facing copy, and new types must use `BagLog`.

## Repository structure

```
BagLog/
├── Project.swift                 # Tuist manifest
├── Tuist.swift                   # Tuist configuration
├── BagLog/                       # Application target and resources
│   ├── Application/               # App entry point and composition root
│   ├── Utility/                   # Small app-specific helpers
│   ├── Design System/             # App-level presentation components
│   └── Resources/ and Localization/
├── DesignSystem/                 # Reusable UI framework
├── Services/                     # App services and Apple framework adapters
├── BagLogTests/                  # Unit tests
├── BagLogUITests/                # UI tests
└── Docs/                         # Product and technical documentation
```

Keep app composition in `BagLog/Application`. Put reusable UI in `DesignSystem` and non-UI integrations or services in `Services`. Do not add unrelated business logic to the application entry point.

## Swift and concurrency

- Use Swift 6 language features and structured concurrency (`async`/`await`, actors, and `@MainActor`) rather than callbacks or `DispatchQueue`.
- Mark UI-facing observable reference types `@MainActor`; use `@Observable`, not `ObservableObject`.
- Prefer value types, immutable `let` properties, descriptive names, and early exits.
- Avoid force unwraps and force `try`; propagate or handle errors with meaningful error types.
- Make values crossing concurrency boundaries `Sendable`; use `@unchecked Sendable` only for an explicitly synchronized implementation.
- Keep functions focused. Extract types or helpers instead of creating long methods or multi-purpose views.

## SwiftUI

- Use SwiftUI's native data flow: `@State`, `@Binding`, `@Environment`, `@Observable`, and `.task(id:)`.
- Do not introduce MVVM by default. Keep view-only state in views and move domain/integration logic into focused services.
- Use `NavigationStack` and `navigationDestination(for:)`; use `Tab`, not `tabItem()`.
- Prefer `foregroundStyle()` to `foregroundColor()` and `clipShape(.rect(cornerRadius:))` to `cornerRadius()`.
- Use `Button` for normal taps, provide text with image-only button labels, and support Dynamic Type.
- Avoid `AnyView`, `GeometryReader` where newer layout APIs work, hard-coded font sizes, and unnecessary fixed spacing.
- Every interactive element needs an appropriate accessibility label; add identifiers when UI automation needs them.

## Data and privacy

- Prefer SwiftData for new persistent relational data. Use `UserDefaults` only for small preferences.
- Request only essential permissions and include clear user-facing usage descriptions.
- Never log sensitive data. Network traffic must use HTTPS.

## Tests and verification

- Add focused unit tests for new business logic and regressions. Add UI tests only when unit tests cannot cover the behavior.
- Use Swift Testing (`@Test`, `#expect`, `#require`) for new tests unless an existing XCTest integration requires XCTest.
- Run `tuist generate --no-open` from the repository root after changing `Project.swift`, target paths, dependencies, or generated-project configuration.
- Build and test the affected scheme on an iOS simulator when source code changes warrant it.

## Documentation

- Keep [Docs/PROJECT_DESCRIPTION.md](Docs/PROJECT_DESCRIPTION.md) aligned with material changes to the product model, monetization, audience, or core user journey.
- Document non-obvious constraints and architectural decisions close to the affected module or in `Docs/`.
