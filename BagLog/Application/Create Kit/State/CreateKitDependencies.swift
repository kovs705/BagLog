//
//  CreateKitDependencies.swift
//  BagLog
//
//  Created by Eugene Kovs on 24.07.2026.
//  https://github.com/kovs705
//

import Persistence

struct CreateKitDependencies {
    let persistence: any BagLogPersisting
    let mediaStore: any MediaStoring
}
