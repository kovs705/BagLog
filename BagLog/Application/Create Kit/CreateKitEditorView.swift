import DesignSystem
import SwiftUI

struct CreateKitEditorView: View {
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool
    let accessibilityTitle: String
    let topics: [CreateKitTopic]

    var body: some View {
        if let draft = Binding($store.draft) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        CreateKitHeroView(
                            draft: draft,
                            store: store,
                            focus: focus,
                            reduceMotion: reduceMotion,
                            accessibilityTitle: accessibilityTitle,
                            topics: topics
                        )

                        VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
                            CreateKitTagEditor(
                                tags: draft.wrappedValue.tagNames,
                                store: store
                            )

                            if let message = store.message {
                                CreateKitInlineMessageView(
                                    message: message,
                                    retry: store.saveState == .failed ? retrySave : nil
                                )
                            }

                            CreateKitItemsSection(
                                items: draft.items,
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
        } else {
            CreateKitErrorView(
                message: "The draft is unavailable.",
                retry: {}
            )
        }
    }

    private func retrySave() {
        Task {
            await store.retrySave()
        }
    }
}
