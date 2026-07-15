//
//  LoadoutSnapshot+KitDetailPresentation.swift
//  BagLog
//
//  Create by Eugene Kovs on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence

extension LoadoutSnapshot {
    var kitDetailVisibilityTitle: String {
        switch visibility {
        case .private: "Private"
        case .public: "Public"
        }
    }

    var kitDetailVisibilitySymbol: String {
        switch visibility {
        case .private: "lock"
        case .public: "globe"
        }
    }
}
