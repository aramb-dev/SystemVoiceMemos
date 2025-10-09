//
//  RecordingEntity.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import Foundation
import SwiftData

@Model
final class RecordingEntity {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: Double
    var fileName: String
    var isFavorite: Bool

    init(id: UUID = UUID(),
         title: String,
         createdAt: Date = .now,
         duration: Double = 0,
         fileName: String,
         isFavorite: Bool = false) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.fileName = fileName
        self.isFavorite = isFavorite
    }
}
