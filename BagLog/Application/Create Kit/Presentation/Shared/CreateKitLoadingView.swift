//
//  CreateKitLoadingView.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

struct CreateKitLoadingView: View {
    var body: some View {
        ProgressView("Opening your kit")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
