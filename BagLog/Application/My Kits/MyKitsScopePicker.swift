import SwiftUI

struct MyKitsScopePicker: View {
    @Binding var selection: MyKitsScope

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: MyKitsDesign.scopeControlPadding) {
            ForEach(MyKitsScope.allCases) { scope in
                Button(scope.title, action: { select(scope) })
                    .font(.headline)
                    .foregroundStyle(selection == scope ? .orange : .primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        Color.primary.opacity(selection == scope ? 0.1 : 0),
                        in: .capsule
                    )
                    .accessibilityAddTraits(selection == scope ? .isSelected : [])
                    .accessibilityIdentifier("my-kits-scope-\(scope.rawValue)")
            }
        }
        .padding(MyKitsDesign.scopeControlPadding)
        .glassEffect(.regular.interactive(), in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func select(_ scope: MyKitsScope) {
        guard scope != selection else { return }

        if reduceMotion {
            selection = scope
        } else {
            withAnimation(.smooth) {
                selection = scope
            }
        }
    }
}
