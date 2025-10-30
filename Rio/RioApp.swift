//
//  RioApp.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SwiftData
import SwiftUI

@main
struct RioApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var bubbleConfig = BubbleConfiguration()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .dynamicTypeSize(.small ... .large) // FIXME: Support more sizes.
//            CursiveTestView()
        }
        .modelContainer(sharedModelContainer)
        .environment(bubbleConfig)
    }
}
