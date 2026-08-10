//
//  WidgetSnapshotService.swift
//  Jimmy
//

import Foundation
import SwiftData
import WidgetKit

/// Regenerates the shared widget snapshot whenever the SwiftData store is
/// saved, so the widget reflects every mutation without polling the store.
@MainActor
final class WidgetSnapshotService {
  private let container: ModelContainer

  init(container: ModelContainer) {
    self.container = container

    NotificationCenter.default.addObserver(
      forName: ModelContext.didSave,
      object: nil,
      queue: .main
    ) { _ in
      MainActor.assumeIsolated {
        self.refresh()
      }
    }

    refresh()
  }

  func refresh() {
    let context = container.mainContext
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    guard
      let monthStart = calendar.date(
        from: calendar.dateComponents([.year, .month], from: today))
    else { return }
    let monthRange = monthStart...today

    let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
    let drinkDays = (try? context.fetch(FetchDescriptor<DrinkDay>())) ?? []
    let saunaDays = (try? context.fetch(FetchDescriptor<SaunaDay>())) ?? []
    let fastingDays = (try? context.fetch(FetchDescriptor<FastingDay>())) ?? []
    let sessions = (try? context.fetch(FetchDescriptor<FastingSession>())) ?? []

    let snapshot = WidgetSnapshot(
      day: today,
      generatedAt: Date(),
      didWorkout: workouts.contains { $0.date == today && $0.didWorkout },
      didNotDrink: drinkDays.contains { $0.date == today && $0.didNotDrink },
      didSauna: saunaDays.contains { $0.date == today && $0.didSauna },
      didFast: fastingDays.contains { $0.date == today && $0.didFast },
      workoutDaysThisMonth: workouts.count { monthRange.contains($0.date) && $0.didWorkout },
      drinkFreeDaysThisMonth: drinkDays.count { monthRange.contains($0.date) && $0.didNotDrink },
      saunaDaysThisMonth: saunaDays.count { monthRange.contains($0.date) && $0.didSauna },
      fastingDaysThisMonth: fastingDays.count { monthRange.contains($0.date) && $0.didFast },
      activeFastStartedAt: sessions.first { $0.isActive }?.startTime
    )

    snapshot.save()
    WidgetCenter.shared.reloadAllTimelines()
  }
}
