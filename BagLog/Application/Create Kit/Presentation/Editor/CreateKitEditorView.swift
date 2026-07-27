//
//  CreateKitEditorView.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import DesignSystem
import Persistence
import SwiftUI

struct CreateKitEditorView: View {
    @Binding var draft: CreateKitDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool
    let accessibilityTitle: String
    let topics: [CreateKitTopic]

    @State private var presentedConflict: LoadoutConflictSnapshot?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    CreateKitHeroView(
                        draft: $draft,
                        store: store,
                        focus: focus,
                        reduceMotion: reduceMotion,
                        accessibilityTitle: accessibilityTitle,
                        topics: topics
                    )

                    VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
                        CreateKitTagEditor(
                            tags: draft.tagNames,
                            store: store
                        )

                        if store.conflict != nil {
                            CreateKitConflictBanner(review: reviewConflict)
                        }

                        if let message = store.message {
                            CreateKitInlineMessageView(
                                message: message,
                                retry: store.saveState == .failed ? retrySave : nil
                            )
                        }

                        CreateKitItemsSection(
                            items: $draft.items,
                            store: store,
                            parentFocus: focus,
                            reduceMotion: reduceMotion
                        )
                    }
                    .padding(.horizontal, CreateKitDesign.horizontalPadding)
                    .padding(.top, CreateKitDesign.sectionSpacing)
                    .padding(.bottom, CreateKitDesign.sectionSpacing)
                }
                .containerRelativeFrame(.horizontal) { length, _ in
                    min(length, 760)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.lastInsertedItemID) { _, itemID in
                scrollToInsertedItem(itemID, using: scrollProxy)
            }
        }
        .safeAreaBar(edge: .bottom) {
            CreateKitComposerBar(
                store: store,
                focus: focus,
                reduceMotion: reduceMotion
            )
        }
        .sensoryFeedback(.increase, trigger: store.itemInsertionCount)
        .sensoryFeedback(.decrease, trigger: store.itemDeletionCount)
        .sensoryFeedback(.alignment, trigger: store.reorderCount)
        .disabled(store.isPublishing)
        .supportNeutralGradientBackground()
        .sheet(item: $presentedConflict) { conflict in
            CreateKitConflictSheet(
                conflict: conflict,
                resolve: store.resolveConflict
            )
        }
    }

    private func retrySave() {
        Task {
            await store.retrySave()
        }
    }

    private func reviewConflict() {
        presentedConflict = store.conflict
    }

    private func scrollToInsertedItem(
        _ itemID: UUID?,
        using scrollProxy: ScrollViewProxy
    ) {
        guard let itemID else { return }

        if reduceMotion {
            scrollProxy.scrollTo(itemID, anchor: .center)
        } else {
            withAnimation(.bouncy) {
                scrollProxy.scrollTo(itemID, anchor: .center)
            }
        }
    }
}
