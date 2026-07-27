import SwiftUI

extension EnvironmentValues {
    @Entry var loadoutSyncTrigger: (@MainActor () -> Void)? = nil
    @Entry var loadoutSyncRetry: (@MainActor () -> Void)? = nil
    @Entry var loadoutSyncDataRevision = 0
}
