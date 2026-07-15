//
//  BagLogPersistence+Environment.swift
//  BagLog
//
//  Created by Eugene on 15.07.2026.
//  https://github.com/kovs705
//

import Persistence
import SwiftUI

extension EnvironmentValues {
    @Entry var bagLogPersistence: (any BagLogPersisting)? = nil
}
