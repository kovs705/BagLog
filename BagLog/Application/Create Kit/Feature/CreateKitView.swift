//
//  CreateKitView.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitView: View {
    @Environment(\.bagLogPersistence) private var persistence
    @Environment(\.bagLogMediaStore) private var mediaStore
    @Environment(\.loadoutSyncTrigger) private var loadoutSyncTrigger

    let presentation: CreateKitPresentation
    let topics: [CreateKitTopic]

    init(
        presentation: CreateKitPresentation,
        topics: [CreateKitTopic] = CreateKitTopic.bundled
    ) {
        self.presentation = presentation
        self.topics = topics
    }

    var body: some View {
        Group {
            if let persistence, let mediaStore {
                CreateKitFlowView(
                    presentation: presentation,
                    topics: topics,
                    dependencies: CreateKitDependencies(
                        persistence: persistence,
                        mediaStore: mediaStore,
                        syncDidChange: loadoutSyncTrigger ?? {}
                    )
                )
            } else {
                CreateKitErrorView(
                    message: "The editor is missing a required local service.",
                    retry: nil
                )
            }
        }
        .presentationSizing(.page)
    }
}
