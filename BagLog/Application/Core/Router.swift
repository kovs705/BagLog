//
//  Router.swift
//  BagLog
//
//  Created by Eugene on 12.07.2026.
//  https://github.com/kovs705
//

import SwiftUI

enum SelectedTab: String {
    case explore
    case profile
    case myKits
}

@MainActor
@Observable final class Router {
    
    var selection: SelectedTab = .explore
    var createKitIsPresented = false
    var debuggerIsPresented: Bool = false
    
}
