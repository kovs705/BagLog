//
//  LoadoutSnapshot+KitDetailPresentation.swift
//  BagLog
//
//  Created by Codex on 15.07.2026.
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
