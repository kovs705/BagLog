//
//  CreateKitLinkDraft.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import Foundation
import Persistence

struct CreateKitLinkDraft: Identifiable, Equatable {
    let id: UUID
    var label: String
    var urlString: String

    init(id: UUID = UUID(), label: String = "", urlString: String = "") {
        self.id = id
        self.label = label
        self.urlString = urlString
    }

    init(snapshot: ItemLinkSnapshot) {
        id = snapshot.id
        label = snapshot.label ?? ""
        urlString = snapshot.urlString
    }

    var command: ItemLinkCommand {
        ItemLinkCommand(
            id: id,
            urlString: urlString,
            label: label
        )
    }

    var isValid: Bool {
        let value = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value) else { return false }
        return url.scheme?.lowercased() == "https" && url.host != nil
    }
}
