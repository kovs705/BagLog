import Foundation
import Sentry

@MainActor
enum BagLogErrorReporting {

    private static let dsnInfoPlistKey = "BAGLOG_SENTRY_DSN"
    private static let verificationLaunchArgument = "--sentry-verification"

    static func start(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) {
        guard let dsn = configuredDSN(in: bundle) else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = isDebugBuild ? "development" : "production"
            options.debug = false

            options.sendDefaultPii = false
            options.maxBreadcrumbs = 0
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableCaptureFailedRequests = false
            options.enableNetworkTracking = false
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false
            options.enableAutoPerformanceTracing = false
            options.enableUIViewControllerTracing = false
            options.enableUserInteractionTracing = false
            options.tracesSampleRate = 0

            options.attachScreenshot = false
            options.attachViewHierarchy = false
            options.reportAccessibilityIdentifier = false
            options.sessionReplay.sessionSampleRate = 0
            options.sessionReplay.onErrorSampleRate = 0

            options.enableLogs = false
            options.enableMetrics = false
            options.enableAutoSessionTracking = false
        }

        #if DEBUG
        if processInfo.arguments.contains(verificationLaunchArgument) {
            captureVerificationError()
            SentrySDK.flush(timeout: 5)
        }
        #endif
    }

    static func capture(error: any Error, operation: String) {
        SentrySDK.capture(message: "Handled operation failed") { scope in
            scope.setLevel(.error)
            scope.setTag(value: operation, key: "operation")
            scope.setTag(
                value: String(reflecting: type(of: error)),
                key: "error.type"
            )
        }
    }

    static func flushBeforeFatalTermination() {
        SentrySDK.flush(timeout: 2)
    }

    private static func configuredDSN(in bundle: Bundle) -> String? {
        guard let rawValue = bundle.object(
            forInfoDictionaryKey: dsnInfoPlistKey
        ) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    #if DEBUG
    private static func captureVerificationError() {
        SentrySDK.capture(message: "BagLog iOS Sentry verification error") {
            scope in
            scope.setLevel(.error)
            scope.setTag(value: "sentry.verification", key: "operation")
        }
    }
    #endif
}
