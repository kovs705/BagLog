import SwiftUI

struct CreateKitItemCard: View {
    @Binding var item: CreateKitItemDraft
    let position: Int
    let isFirst: Bool
    let isLast: Bool
    @Bindable var store: CreateKitStore
    let parentFocus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool

    @State private var editorDestination: CreateKitItemEditorDestination?
    @State private var isConfirmingDelete = false
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: CreateKitDesign.cardSpacing) {
            VStack(spacing: 2) {
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline)

                Text(position, format: .number.precision(.integerLength(2)))
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(.tertiary)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .draggable(CreateKitItemTransfer(id: item.id)) {
                Label(itemTitle, systemImage: itemSymbol)
                    .font(.headline)
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
            }
            .accessibilityLabel("Reorder \(itemTitle)")
            .accessibilityHint("Drag, or use the item actions menu")

            Button(action: presentEditor) {
                HStack(spacing: CreateKitDesign.cardSpacing) {
                    Image(systemName: itemSymbol)
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .frame(width: 42, height: 42)
                        .background(.orange.opacity(0.12), in: .rect(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(itemTitle)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            if item.isEssential {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel("Essential item")
                            }
                        }

                        Text(itemSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens item details in a sheet")
            .accessibilityIdentifier("edit-item-\(item.id.uuidString)")

            Menu("Item actions", systemImage: "ellipsis") {
                Button("Move up", systemImage: "arrow.up", action: moveUp)
                    .disabled(isFirst)
                Button("Move down", systemImage: "arrow.down", action: moveDown)
                    .disabled(isLast)
                Divider()
                Button("Delete item", systemImage: "trash", role: .destructive, action: confirmDelete)
            }
            .labelStyle(.iconOnly)
            .tint(.secondary)
            .frame(minWidth: 44, minHeight: 44)
            .background(.quaternary, in: .circle)
            .confirmationDialog(
                "Delete \(itemTitle)?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete item", role: .destructive, action: deleteItem)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the item and its links from the draft.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .rect(cornerRadius: CreateKitDesign.itemCornerRadius))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: CreateKitDesign.itemCornerRadius)
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 3, dash: [8, 5])
                    )
            }
        }
        .dropDestination(for: CreateKitItemTransfer.self, action: handleDrop)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .snappy, value: isDropTarget)
        .accessibilityAction(named: "Move up", moveUp)
        .accessibilityAction(named: "Move down", moveDown)
        .sheet(item: $editorDestination) { _ in
            CreateKitItemEditorSheet(
                item: $item,
                store: store
            )
        }
    }

    private var itemTitle: String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled item" : title
    }

    private var itemSymbol: String {
        switch item.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "tech": "laptopcomputer"
        case "clothing": "tshirt"
        case "documents": "doc.text"
        case "tools": "hammer"
        case "care": "cross.case"
        default: "shippingbox"
        }
    }

    private var itemSummary: String {
        let category = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let brandAndModel = [item.brand, item.model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let quantity = item.quantity > 1 ? "\(item.quantity)×" : ""
        let linkCount: String
        switch item.links.count {
        case 0:
            linkCount = ""
        case 1:
            linkCount = "1 link"
        default:
            linkCount = "\(item.links.count) links"
        }
        let details = [quantity, category, brandAndModel, linkCount].filter { !$0.isEmpty }
        return details.isEmpty ? "Add details" : details.joined(separator: " · ")
    }

    private func presentEditor() {
        parentFocus.wrappedValue = nil
        editorDestination = CreateKitItemEditorDestination(id: item.id)
    }

    private func moveUp() {
        store.moveItemUp(id: item.id)
    }

    private func moveDown() {
        store.moveItemDown(id: item.id)
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }

    private func deleteItem() {
        store.removeItem(id: item.id)
    }

    private func handleDrop(
        _ transfers: [CreateKitItemTransfer],
        _ session: DropSession
    ) {
        switch session.phase {
        case .entering, .active:
            isDropTarget = true
            guard let transfer = transfers.first else { return }
            store.moveItem(id: transfer.id, before: item.id)
        case .exiting, .ended, .dataTransferCompleted:
            isDropTarget = false
        @unknown default:
            isDropTarget = false
        }
    }
}
