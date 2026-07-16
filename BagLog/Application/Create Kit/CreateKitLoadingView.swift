import SwiftUI

struct CreateKitLoadingView: View {
    var body: some View {
        ProgressView("Opening your kit")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
