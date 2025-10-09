//
//  SystemVoiceMemosApp.swift
//  SystemVoiceMemos
//
//  Created by Abdur-Rahman Abu Musa Bilal on 10/8/25.
//

import SwiftUI
import SwiftData

@main
struct SystemVoiceMemosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()   // works because we added init() {}
        }
        .modelContainer(for: RecordingEntity.self)
    }
}
