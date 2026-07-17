import SwiftUI

struct MyKitsLibraryHeader: View {
    @Binding var scope: MyKitsScope
    let createKit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MyKitsDesign.sectionSpacing) {
            HStack(alignment: .center) {
                Text("My Kits")
                    .font(.largeTitle.scaled(by: 1.25))
                    .fontDesign(.serif)
                    .bold()
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button("Create kit", systemImage: "plus", action: createKit)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityIdentifier("create-kit-from-library")
            }

            MyKitsScopePicker(selection: $scope)
        }
    }
}
