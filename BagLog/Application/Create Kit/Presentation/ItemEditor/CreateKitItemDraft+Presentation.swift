//
//  CreateKitItemDraft+Presentation.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import Foundation

extension CreateKitItemDraft {
    var createKitDisplayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled item" : trimmedTitle
    }

    var createKitSymbol: String {
        switch category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "tech": "laptopcomputer"
        case "clothing": "tshirt"
        case "documents": "doc.text"
        case "tools": "hammer"
        case "care": "cross.case"
        default: "shippingbox"
        }
    }

    var createKitSummary: String {
        let category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let brandAndModel = [brand, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let quantity = quantity > 1 ? "\(quantity)×" : ""
        let linkCount = switch links.count {
        case 0: ""
        case 1: "1 link"
        default: "\(links.count) links"
        }
        let details = [quantity, category, brandAndModel, linkCount]
            .filter { !$0.isEmpty }

        return details.isEmpty ? "Add details" : details.joined(separator: " · ")
    }
}
