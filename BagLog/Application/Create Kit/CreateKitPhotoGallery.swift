import PhotosUI
import SwiftUI

struct CreateKitPhotoGallery: View {
    let photos: [CreateKitPhotoDraft]
    @Bindable var store: CreateKitStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            HStack {
                Label("Kit photos", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)

                Spacer()

                Text("\(photos.count) of 3")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if photos.isEmpty {
                PhotosPicker(
                    selection: $selection,
                    maxSelectionCount: 3,
                    selectionBehavior: .ordered,
                    matching: .images
                ) {
                    VStack(spacing: CreateKitDesign.cardSpacing) {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Add real context")
                            .font(.headline)

                        Text("Choose up to three photos. The first becomes the cover.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add kit photos")
                .accessibilityHint("Choose up to three photos. The first becomes the cover.")
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: CreateKitDesign.cardSpacing) {
                        ForEach(photos.enumerated(), id: \.element.id) { index, photo in
                            CreateKitPhotoCard(
                                photo: photo,
                                isCover: index == 0,
                                isFirst: index == 0,
                                isLast: index == photos.index(before: photos.endIndex),
                                store: store
                            )
                        }

                        if photos.count < 3 {
                            PhotosPicker(
                                selection: $selection,
                                maxSelectionCount: 3 - photos.count,
                                selectionBehavior: .ordered,
                                matching: .images
                            ) {
                                Label("Add photos", systemImage: "plus")
                                    .frame(minWidth: 112, minHeight: CreateKitDesign.galleryHeight)
                                    .background(.thinMaterial, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            if store.isImportingPhoto {
                ProgressView("Preparing photo")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: CreateKitDesign.cardCornerRadius))
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .snappy,
            value: photos.map(\.id)
        )
        .onChange(of: selection, importSelection)
    }

    private func importSelection() {
        let selectedItems = selection
        selection = []

        Task {
            for selectedItem in selectedItems {
                do {
                    guard let importedPhoto = try await selectedItem.loadTransferable(
                        type: CreateKitPhotoImport.self
                    ) else {
                        store.message = "That photo format isn’t supported."
                        continue
                    }

                    await store.importPhoto(at: importedPhoto.fileURL)
                } catch {
                    store.message = "That photo couldn’t be loaded."
                }
            }
        }
    }
}
