//
//  RecordingEntity.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//
//  SwiftData model representing a voice recording.
//

import Foundation
import SwiftData

/// Represents a voice recording in the database
///
/// This model stores:
/// - Recording metadata (title, creation date, duration)
/// - File reference (fileName)
/// - Organization (folder, favorite status)
/// - Deletion state (soft delete with deletedAt)
@Model
final class RecordingEntity: Identifiable {
    /// Unique identifier
    var id: UUID
    
    /// User-visible title
    var title: String
    
    /// Creation timestamp
    var createdAt: Date
    
    /// Duration in seconds
    var duration: Double
    
    /// File name in recordings directory
    var fileName: String
    
    /// Whether marked as favorite
    var isFavorite: Bool
    
    /// Optional folder for organization
    var folder: String?
    
    /// Soft delete timestamp (nil if not deleted)
    var deletedAt: Date?

    init(id: UUID = UUID(),
         title: String,
         createdAt: Date = .now,
         duration: Double = 0,
         fileName: String,
         isFavorite: Bool = false,
         folder: String? = nil,
         deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.fileName = fileName
        self.isFavorite = isFavorite
        self.folder = folder
        self.deletedAt = deletedAt
    }
}
