//
//  LoadoutSnapshot+MyKitsPresentation.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence

extension LoadoutSnapshot {
    var myKitsCategoryTitle: String {
        switch category {
        case .everydayCarry: "Everyday Carry"
        case .travel: "Travel"
        case .cycling: "Cycling"
        case .camera: "Camera"
        case .work: "Work"
        case .outdoor: "Outdoor"
        case .emergency: "Emergency"
        case .fitness: "Fitness"
        case .parenting: "Parenting"
        case .other: "Other"
        }
    }

    var myKitsCategorySymbol: String {
        switch category {
        case .everydayCarry: "briefcase"
        case .travel: "suitcase"
        case .cycling: "bicycle"
        case .camera: "camera"
        case .work: "laptopcomputer"
        case .outdoor: "figure.hiking"
        case .emergency: "cross.case"
        case .fitness: "dumbbell"
        case .parenting: "figure.and.child.holdinghands"
        case .other: "backpack"
        }
    }

    var myKitsStatusTitle: String {
        switch status {
        case .draft: "Draft"
        case .published: "Published locally"
        case .archived: "Archived"
        }
    }

    var myKitsStatusSymbol: String {
        switch status {
        case .draft: "pencil"
        case .published: "checkmark.seal"
        case .archived: "archivebox"
        }
    }

    var myKitsItemCountTitle: String {
        let itemCount = items.count
        return itemCount == 1 ? "1 item" : "\(itemCount) items"
    }
}
