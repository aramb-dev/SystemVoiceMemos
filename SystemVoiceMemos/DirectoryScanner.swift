//
//  DirectoryScanner.swift
//  SystemVoiceMemos
//
//  Reconciles the recordings directory with SwiftData on launch.
//  Discovers M4A files not yet tracked and marks missing files appropriately.
//  Uses URL resource keys to detect cloud-only files without triggering downloads.
//

import Foundation
import SwiftData
import AVFoundation

enum DirectoryScanner {

    /// Reconciles the filesystem with SwiftData.
    /// - Discovers untracked .m4a files and creates RecordingEntity entries
    /// - Marks existing entries whose files are cloud-only
    /// - Soft-deletes entries whose files are truly gone from disk
    @MainActor
    static func reconcile(context: ModelContext) async {
        guard let recordingsDir = try? AppDirectories.recordingsDir() else { return }

        let fm = FileManager.default

        // Fetch all existing recordings from the database
        let descriptor = FetchDescriptor<RecordingEntity>()
        guard let existingRecordings = try? context.fetch(descriptor) else { return }

        // Build a lookup from fileName -> RecordingEntity
        var trackedByFileName: [String: RecordingEntity] = [:]
        for rec in existingRecordings {
            trackedByFileName[rec.fileName] = rec
        }

        // Enumerate .m4a files in the recordings directory (shallow)
        let resourceKeys: Set<URLResourceKey> = [
            .nameKey,
            .creationDateKey,
            .isRegularFileKey,
            .ubiquitousItemDownloadingStatusKey,
        ]

        guard let enumerator = fm.enumerator(
            at: recordingsDir,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        var foundFileNames: Set<String> = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "m4a" else { continue }

            let fileName = fileURL.lastPathComponent
            foundFileNames.insert(fileName)

            let isCloud = isCloudOnly(url: fileURL)

            if let existing = trackedByFileName[fileName] {
                // Update cloud status on the existing entity
                existing.isCloudOnly = isCloud
            } else {
                // Create a new RecordingEntity for this untracked file
                let title = titleFromFileName(fileName)
                let createdAt = creationDate(for: fileURL) ?? .now

                var duration: Double = 0
                if !isCloud {
                    duration = await loadDuration(url: fileURL)
                }

                let entity = RecordingEntity(
                    title: title,
                    createdAt: createdAt,
                    duration: duration,
                    fileName: fileName
                )
                entity.isCloudOnly = isCloud
                context.insert(entity)
            }
        }

        // Handle DB entries whose files are missing from disk
        for rec in existingRecordings where rec.deletedAt == nil {
            guard !foundFileNames.contains(rec.fileName) else { continue }

            let fileURL = recordingsDir.appendingPathComponent(rec.fileName)
            let cloudStatus = isCloudOnly(url: fileURL)

            if cloudStatus {
                // File exists in the cloud but wasn't enumerated locally
                rec.isCloudOnly = true
            } else {
                // File is truly gone — soft-delete the entry
                rec.deletedAt = .now
            }
        }

        try? context.save()
    }

    // MARK: - Cloud Detection

    /// Checks whether a file is cloud-only (not downloaded locally).
    /// Uses ubiquitousItemDownloadingStatus for iCloud Drive files,
    /// falls back to fileExists for other cloud providers.
    private static func isCloudOnly(url: URL) -> Bool {
        let fm = FileManager.default

        // Try iCloud-specific resource key
        if let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
           let status = values.ubiquitousItemDownloadingStatus {
            switch status {
            case .current, .downloaded:
                return false
            case .notDownloaded:
                return true
            default:
                return false
            }
        }

        // Fallback: check if the file physically exists on disk
        // For non-iCloud cloud providers (Dropbox, Google Drive), placeholder
        // files may exist but the actual data isn't available.
        // .m4a stubs from cloud providers are typically very small.
        if fm.fileExists(atPath: url.path) {
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                // A real M4A file should be at least a few KB;
                // cloud placeholder stubs are typically < 1KB
                return size < 1024
            }
            return false
        }

        // File doesn't exist at all
        return true
    }

    // MARK: - Helpers

    /// Derives a display title from an M4A filename.
    /// Strips the extension and replaces underscores/hyphens with spaces.
    private static func titleFromFileName(_ fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        return stem
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    /// Reads the file's creation date from filesystem metadata.
    private static func creationDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey])
        return values?.creationDate
    }

    /// Loads the audio duration for a local file.
    private static func loadDuration(url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            return (seconds.isFinite && seconds > 0.01) ? seconds : 0
        } catch {
            return 0
        }
    }
}
