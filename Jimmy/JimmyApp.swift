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
    let sharedModelContainer: ModelContainer
    @State private var syncMonitor: CloudSyncMonitor
    private let snapshotService: WidgetSnapshotService
    @Environment(\.scenePhase) private var scenePhase

    init() {
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
            sharedModelContainer = try ModelContainer(
                for: schema, configurations: [cloudConfiguration])
            _syncMonitor = State(initialValue: CloudSyncMonitor(isCloudSyncEnabled: true))
        } catch {
            print("CloudKit setup failed, using local storage: \(error)")
            // Fallback to local storage
            let localConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            do {
                sharedModelContainer = try ModelContainer(
                    for: schema, configurations: [localConfiguration])
                _syncMonitor = State(initialValue: CloudSyncMonitor(isCloudSyncEnabled: false))
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
        snapshotService = WidgetSnapshotService(container: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                    .frame(minWidth: 700, minHeight: 620)
                #endif
        }
        .defaultSize(width: 900, height: 760)
        .modelContainer(sharedModelContainer)
        .environment(syncMonitor)
        .onChange(of: scenePhase) { _, newPhase in
            // Catch changes that arrive outside ModelContext.didSave, such as
            // CloudKit imports applied while the app was inactive.
            if newPhase == .active || newPhase == .background {
                snapshotService.refresh()
            }
        }
    }
}
