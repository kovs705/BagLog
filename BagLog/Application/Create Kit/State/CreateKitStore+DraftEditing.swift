//
//  CreateKitStore+DraftEditing.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import Foundation

extension CreateKitStore {
    func addComposedItem() {
        guard let itemID = draft?.addItem(named: composerText) else { return }
        didInsertItem(id: itemID)
    }

    func addTag(_ value: String) {
        guard draft?.addTag(value) == true else { return }
        markStructureChanged()
    }

    func removeTag(_ tag: String) {
        guard draft?.removeTag(tag) == true else { return }
        markStructureChanged()
    }

    func addLink(to itemID: UUID) {
        guard draft?.addLink(to: itemID) == true else { return }
        markStructureChanged()
    }

    func removeLink(id linkID: UUID, from itemID: UUID) {
        guard draft?.removeLink(id: linkID, from: itemID) == true else { return }
        markStructureChanged()
    }

    func removeItem(id: UUID) {
        guard draft?.removeItem(id: id) == true else { return }
        didDeleteItem()
    }

    func moveItemUp(id: UUID) {
        guard draft?.moveItemUp(id: id) == true else { return }
        didReorder()
    }

    func moveItemDown(id: UUID) {
        guard draft?.moveItemDown(id: id) == true else { return }
        didReorder()
    }

    func moveItem(id: UUID, before targetID: UUID) {
        guard draft?.moveItem(id: id, before: targetID) == true else { return }
        didReorder()
    }

    func makeCover(photoID: UUID) {
        guard draft?.makeCover(photoID: photoID) == true else { return }
        didReorder()
    }

    func movePhotoEarlier(id: UUID) {
        guard draft?.movePhotoEarlier(id: id) == true else { return }
        didReorder()
    }

    func movePhotoLater(id: UUID) {
        guard draft?.movePhotoLater(id: id) == true else { return }
        didReorder()
    }

    func movePhoto(id: UUID, before targetID: UUID) {
        guard draft?.movePhoto(id: id, before: targetID) == true else { return }
        didReorder()
    }
}
