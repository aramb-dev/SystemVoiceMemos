//
//  FolderEntity.swift
//  SystemVoiceMemos
//

import Foundation
import SwiftData

@Model
final class FolderEntity: Identifiable {
    var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    
    init(id: UUID = UUID(),
         name: String,
         createdAt: Date = .now,
         sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}
