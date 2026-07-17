import PhotosUI
import SwiftUI

struct CreateKitPhotoGallery: View {
    let photos: [CreateKitPhotoDraft]
    @Bindable var store: CreateKitStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            if photos.isEmpty {
                PhotosPicker(
                    selection: $selection,
                    maxSelectionCount: 3,
                    selectionBehavior: .ordered,
                    matching: .images
                ) {
                    Label("Add cover photos", systemImage: "photo.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(.white.opacity(0.14), in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add kit photos")
                .accessibilityHint("Choose up to three photos. The first becomes the cover.")

                Text("Add up to three photos. The first becomes the cover.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: CreateKitDesign.cardSpacing) {
                        ForEach(photos.enumerated(), id: \.element.id) { index, photo in
                            CreateKitPhotoCard(
                                photo: photo,
                                position: index + 1,
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
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(
                                        width: CreateKitDesign.heroPhotoWidth,
                                        height: CreateKitDesign.heroPhotoHeight
                                    )
                                    .background(.white.opacity(0.12), in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: CreateKitDesign.compactCornerRadius)
                                            .stroke(
                                                .white.opacity(0.52),
                                                style: StrokeStyle(lineWidth: 1, dash: [7, 5])
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add more kit photos")
                        }
                    }
                }
                .scrollIndicators(.hidden)

                Text("Photo 1 is the cover · \(photos.count) of 3")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            if store.isImportingPhoto {
                ProgressView("Preparing photo")
                    .font(.subheadline)
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
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
