//
//  CreateKitDraft+Editing.swift
//  BagLog
//
//  Created by Eugene Kovs on 25.07.2026.
//  https://github.com/kovs705
//

import Foundation

extension CreateKitDraft {
    var canAddPhoto: Bool {
        photos.count < Self.maximumPhotoCount
    }

    var remainingPhotoCapacity: Int {
        max(0, Self.maximumPhotoCount - photos.count)
    }

    @discardableResult
    mutating func addItem(named value: String) -> UUID? {
        let title = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let item = CreateKitItemDraft(title: title)
        items.append(item)
        return item.id
    }

    @discardableResult
    mutating func addTag(_ value: String) -> Bool {
        let tag = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        guard !tagNames.contains(where: {
            $0.caseInsensitiveCompare(tag) == .orderedSame
        }) else {
            return false
        }

        tagNames.append(tag)
        return true
    }

    @discardableResult
    mutating func removeTag(_ tag: String) -> Bool {
        let initialCount = tagNames.count
        tagNames.removeAll { $0 == tag }
        return tagNames.count != initialCount
    }

    @discardableResult
    mutating func addLink(to itemID: UUID) -> Bool {
        guard let itemIndex = items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }

        items[itemIndex].links.append(CreateKitLinkDraft())
        return true
    }

    @discardableResult
    mutating func removeLink(id linkID: UUID, from itemID: UUID) -> Bool {
        guard let itemIndex = items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }

        let initialCount = items[itemIndex].links.count
        items[itemIndex].links.removeAll { $0.id == linkID }
        return items[itemIndex].links.count != initialCount
    }

    @discardableResult
    mutating func removeItem(id: UUID) -> Bool {
        let initialCount = items.count
        items.removeAll { $0.id == id }
        return items.count != initialCount
    }

    @discardableResult
    mutating func moveItemUp(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }),
              index > items.startIndex else {
            return false
        }

        items.swapAt(index, items.index(before: index))
        return true
    }

    @discardableResult
    mutating func moveItemDown(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }),
              index < items.index(before: items.endIndex) else {
            return false
        }

        items.swapAt(index, items.index(after: index))
        return true
    }

    @discardableResult
    mutating func moveItem(id: UUID, before targetID: UUID) -> Bool {
        items.move(id: id, before: targetID)
    }

    mutating func addPhoto(_ photo: CreateKitPhotoDraft) {
        guard canAddPhoto else { return }
        photos.append(photo)
    }

    @discardableResult
    mutating func makeCover(photoID: UUID) -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == photoID }),
              index != photos.startIndex else {
            return false
        }

        let photo = photos.remove(at: index)
        photos.insert(photo, at: photos.startIndex)
        return true
    }

    @discardableResult
    mutating func movePhotoEarlier(id: UUID) -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == id }),
              index > photos.startIndex else {
            return false
        }

        photos.swapAt(index, photos.index(before: index))
        return true
    }

    @discardableResult
    mutating func movePhotoLater(id: UUID) -> Bool {
        guard let index = photos.firstIndex(where: { $0.id == id }),
              index < photos.index(before: photos.endIndex) else {
            return false
        }

        photos.swapAt(index, photos.index(after: index))
        return true
    }

    @discardableResult
    mutating func movePhoto(id: UUID, before targetID: UUID) -> Bool {
        photos.move(id: id, before: targetID)
    }

    @discardableResult
    mutating func removePhoto(id: UUID) -> CreateKitPhotoDraft? {
        guard let index = photos.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return photos.remove(at: index)
    }

}

private extension Array where Element: Identifiable, Element.ID: Equatable {
    mutating func move(id: Element.ID, before targetID: Element.ID) -> Bool {
        guard id != targetID,
              let sourceIndex = firstIndex(where: { $0.id == id }),
              let targetIndex = firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        let element = remove(at: sourceIndex)
        let destinationIndex = sourceIndex < targetIndex
            ? index(before: targetIndex)
            : targetIndex
        insert(element, at: destinationIndex)
        return sourceIndex != destinationIndex
    }
}
