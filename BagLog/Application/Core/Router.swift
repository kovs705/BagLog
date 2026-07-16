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
    var createKitPresentation: CreateKitPresentation?
    var myKitsPath: [MyKitsRoute] = []
    private(set) var kitsRevision = 0
    var debuggerIsPresented: Bool = false

    private var pendingPublishedLoadoutID: UUID?

    func presentNewKit() {
        createKitPresentation = .new
    }

    func presentEditor(loadoutID: UUID) {
        createKitPresentation = .edit(loadoutID)
    }

    func dismissEditor() {
        createKitPresentation = nil
    }

    func finishPublishing(loadoutID: UUID) {
        pendingPublishedLoadoutID = loadoutID
        createKitPresentation = nil
    }

    func editorDidDismiss() {
        kitsRevision += 1

        guard let pendingPublishedLoadoutID else { return }
        self.pendingPublishedLoadoutID = nil
        selection = .myKits
        myKitsPath = [.detail(pendingPublishedLoadoutID)]
    }

}
