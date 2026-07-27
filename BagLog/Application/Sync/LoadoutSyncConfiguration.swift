import Foundation

struct LoadoutSyncConfiguration: Sendable, Equatable {
    let isEnabled: Bool

    init(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) {
#if DEBUG
        if processInfo.arguments.contains("--private-sync-enabled") {
            isEnabled = true
            return
        }
        guard let value = bundle.object(
            forInfoDictionaryKey: "BAGLOG_PRIVATE_SYNC_ENABLED"
        ) as? String else {
            isEnabled = false
            return
        }
        isEnabled = value == "YES"
#else
        isEnabled = false
#endif
    }
}
