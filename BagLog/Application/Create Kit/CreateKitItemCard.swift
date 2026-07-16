import SwiftUI

struct CreateKitItemCard: View {
    @Binding var item: CreateKitItemDraft
    let isExpanded: Bool
    let isFirst: Bool
    let isLast: Bool
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding
    let reduceMotion: Bool

    @State private var isConfirmingDelete = false
    @State private var isDropTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: CreateKitDesign.cardSpacing) {
            HStack(spacing: CreateKitDesign.cardSpacing) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                    .draggable(CreateKitItemTransfer(id: item.id)) {
                        Label(item.title.isEmpty ? "Untitled item" : item.title, systemImage: "shippingbox")
                            .font(.headline)
                            .padding()
                            .background(.regularMaterial, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
                    }
                    .accessibilityLabel("Reorder \(item.title)")
                    .accessibilityHint("Drag, or use the item actions menu")

                Button(action: toggleExpanded) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title.isEmpty ? "Untitled item" : item.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(itemSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Collapses item details" : "Expands item details")

                Menu("Item actions", systemImage: "ellipsis") {
                    Button("Move up", systemImage: "arrow.up", action: moveUp)
                        .disabled(isFirst)
                    Button("Move down", systemImage: "arrow.down", action: moveDown)
                        .disabled(isLast)
                    Divider()
                    Button("Delete item", systemImage: "trash", role: .destructive, action: confirmDelete)
                }
                .frame(minWidth: 44, minHeight: 44)
                .confirmationDialog(
                    "Delete \(item.title.isEmpty ? "this item" : item.title)?",
                    isPresented: $isConfirmingDelete,
                    titleVisibility: .visible
                ) {
                    Button("Delete item", role: .destructive, action: deleteItem)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the item and its links from the draft.")
                }
            }

            if isExpanded {
                Divider()

                CreateKitItemDetailsView(
                    item: $item,
                    store: store,
                    focus: focus
                )
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(.background, in: .rect(cornerRadius: CreateKitDesign.cardCornerRadius))
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: CreateKitDesign.cardCornerRadius)
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 3, dash: [8, 5])
                    )
            } else if isExpanded {
                RoundedRectangle(cornerRadius: CreateKitDesign.cardCornerRadius)
                    .stroke(Color.orange, lineWidth: 2)
            }
        }
        .dropDestination(for: CreateKitItemTransfer.self, action: handleDrop)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .snappy, value: isExpanded)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .snappy, value: isDropTarget)
        .accessibilityAction(named: "Move up", moveUp)
        .accessibilityAction(named: "Move down", moveDown)
    }

    private var itemSummary: String {
        let category = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity = item.quantity > 1 ? "\(item.quantity)×" : ""
        let details = [quantity, category].filter { !$0.isEmpty }
        return details.isEmpty ? "Tap for details" : details.joined(separator: " · ")
    }

    private func toggleExpanded() {
        store.toggleExpandedItem(id: item.id)
        if !isExpanded {
            focus.wrappedValue = .itemTitle(item.id)
        }
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
        focus.wrappedValue = .composer
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
