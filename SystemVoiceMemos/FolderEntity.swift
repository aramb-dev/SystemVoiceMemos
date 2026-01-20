//
//  FolderEntity.swift
//  SystemVoiceMemos
//
//  SwiftData model for persistent folder storage.
//

import Foundation
import SwiftData

/// Represents a folder for organizing recordings
///
/// Folders persist independently of recordings and can be empty.
/// The sortOrder property allows custom folder ordering in the UI.
@Model
final class FolderEntity: Identifiable {
    /// Unique identifier
    var id: UUID
    
    /// Folder name
    var name: String
    
    /// Creation timestamp
    var createdAt: Date
    
    /// Custom sort order for sidebar display
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
