import DesignSystem
import SwiftUI

struct CreateKitProfileGateView: View {
    @Bindable var store: CreateKitStore
    let focus: FocusState<CreateKitFocusField?>.Binding

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CreateKitDesign.sectionSpacing) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("First, make this kit yours")
                    .font(.largeTitle)
                    .bold()

                Text("BagLog is local-only for now. This name and handle stay on this device and identify the kits you create.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                TextField("Display name", text: $store.profileDisplayName)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused(focus, equals: .profileDisplayName)
                    .onSubmit(focusHandle)
                    .padding()
                    .background(.background, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
                    .accessibilityIdentifier("profile-display-name")

                TextField("Handle", text: $store.profileHandle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused(focus, equals: .profileHandle)
                    .onSubmit(createProfile)
                    .padding()
                    .background(.background, in: .rect(cornerRadius: CreateKitDesign.compactCornerRadius))
                    .accessibilityIdentifier("profile-handle")

                if let message = store.message {
                    CreateKitInlineMessageView(message: message, retry: nil)
                }

                Button("Continue", systemImage: "arrow.right", action: createProfile)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isCreatingProfile)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityIdentifier("profile-continue")
            }
            .padding(CreateKitDesign.horizontalPadding)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .supportNeutralGradientBackground()
    }

    private func focusHandle() {
        focus.wrappedValue = .profileHandle
    }

    private func createProfile() {
        Task {
            do {
                try await store.createProfile()
            } catch {
                if store.message == nil {
                    store.message = "Your local profile couldn’t be created."
                }
            }
        }
    }
}
