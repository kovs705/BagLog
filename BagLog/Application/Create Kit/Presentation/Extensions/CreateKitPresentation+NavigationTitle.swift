//
//  CreateKitPresentation+NavigationTitle.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

extension CreateKitPresentation {
    var createKitNavigationTitle: String {
        switch self {
        case .new: "New kit"
        case .edit: "Edit kit"
        }
    }
}
