import SwiftUI

struct CreateKitHeroView: View {
    @Binding var draft: CreateKitDraft
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool
    let accessibilityTitle: String
    let topics: [CreateKitTopic]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
            if dynamicTypeSize.isAccessibilitySize {
                CreateKitSaveBadge(
                    state: store.saveState,
                    label: store.saveStateLabel
                )
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.black.opacity(0.3), in: .capsule)
                .environment(\.colorScheme, .dark)
            }

            CreateKitHeaderView(
                draft: $draft,
                store: store,
                focus: focus,
                accessibilityTitle: accessibilityTitle,
                topics: topics
            )

            CreateKitPhotoGallery(
                photos: draft.photos,
                store: store
            )
        }
        .padding(.horizontal, CreateKitDesign.horizontalPadding)
        .padding(.top, CreateKitDesign.heroContentTopPadding)
        .padding(.bottom, CreateKitDesign.heroContentBottomPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize
                ? CreateKitDesign.heroAccessibilityMinimumHeight
                : CreateKitDesign.heroMinimumHeight,
            alignment: .bottomLeading
        )
        .background {
            CreateKitHeroBackground(coverPhoto: draft.photos.first)
        }
        .clipped()
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .smooth,
            value: draft.photos.first?.id
        )
        .overlay(alignment: .top) {
            if !dynamicTypeSize.isAccessibilitySize {
                CreateKitSaveBadge(
                    state: store.saveState,
                    label: store.saveStateLabel
                )
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.black.opacity(0.3), in: .capsule)
                .environment(\.colorScheme, .dark)
                .padding(.top, 56)
            }
        }
    }
}
