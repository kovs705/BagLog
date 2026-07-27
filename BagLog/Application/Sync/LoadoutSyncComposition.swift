import Foundation
import Persistence
import Services

@MainActor
enum LoadoutSyncComposition {
    static func make(
        configuration: LoadoutSyncConfiguration,
        apiBaseURL: URL?,
        sessionController: any BagLogSessionControlling,
        persistence: any BagLogSyncPersisting,
        processInfo: ProcessInfo = .processInfo
    ) -> LoadoutSyncCoordinator {
        let api: any BagLogLoadoutAPIProviding
#if DEBUG
        if processInfo.arguments.contains("--ui-testing") {
            api = LoadoutSyncUITestAPI()
        } else {
            api = BagLogLoadoutAPI(
                baseURL: apiBaseURL,
                accessTokenProvider: sessionController
            )
        }
#else
        api = BagLogLoadoutAPI(
            baseURL: apiBaseURL,
            accessTokenProvider: sessionController
        )
#endif
        return LoadoutSyncCoordinator(
            configuration: configuration,
            engine: LoadoutSyncEngine(api: api, persistence: persistence),
            persistence: persistence
        )
    }
}
