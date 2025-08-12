//
//  JimmyApp.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct JimmyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Workout.self,
            DrinkDay.self,
            SaunaDay.self,
            FastingDay.self,
            FastingSession.self,
            Exercise.self,
            ExerciseEntry.self,
            ExerciseSet.self,
            MeasurementType.self,
            MeasurementEntry.self,
            AppSettings.self,
        ])
        
        // Try CloudKit first, fallback to local storage if it fails
        do {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            print("CloudKit setup failed, using local storage: \(error)")
            // Fallback to local storage
            let localConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
