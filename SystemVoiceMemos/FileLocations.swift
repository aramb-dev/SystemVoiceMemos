//
//  FileLocations.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//
import Foundation

enum AppDirectories {
    static let appFolderName = "SystemVoiceMemos"

    static func recordingsDir() throws -> URL {
        let fm = FileManager.default

        // Use custom location if the user has set one
        let customPath = UserDefaults.standard.string(forKey: "recordingsLocation") ?? ""
        if !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath, isDirectory: true)
            if !fm.fileExists(atPath: customURL.path) {
                try fm.createDirectory(at: customURL, withIntermediateDirectories: true)
            }
            return customURL
        }

        // Default: ~/Library/Application Support/SystemVoiceMemos/
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent(appFolderName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
