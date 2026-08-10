//
//  WidgetSnapshot.swift
//  Jimmy
//
//  Shared between the app and the widget extension.
//

import Foundation

/// A compact summary of today's habit tracking, written by the app to the
/// shared app group after each data mutation and read by the widget.
struct WidgetSnapshot: Codable {
  static let appGroupID = "group.com.chacons.Jimmy"
  private static let defaultsKey = "widgetSnapshot"

  /// Start of the day this snapshot describes; the widget ignores the
  /// per-day flags when this is no longer today.
  var day: Date
  var generatedAt: Date

  var didWorkout: Bool
  var didNotDrink: Bool
  var didSauna: Bool
  var didFast: Bool

  var workoutDaysThisMonth: Int
  var drinkFreeDaysThisMonth: Int
  var saunaDaysThisMonth: Int
  var fastingDaysThisMonth: Int

  /// Start time of the currently running fasting session, if any.
  var activeFastStartedAt: Date?

  static func load() -> WidgetSnapshot? {
    guard
      let defaults = UserDefaults(suiteName: appGroupID),
      let data = defaults.data(forKey: defaultsKey)
    else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }

  func save() {
    guard
      let defaults = UserDefaults(suiteName: Self.appGroupID),
      let data = try? JSONEncoder().encode(self)
    else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }

  static var placeholder: WidgetSnapshot {
    WidgetSnapshot(
      day: Calendar.current.startOfDay(for: Date()),
      generatedAt: Date(),
      didWorkout: true,
      didNotDrink: true,
      didSauna: false,
      didFast: false,
      workoutDaysThisMonth: 12,
      drinkFreeDaysThisMonth: 18,
      saunaDaysThisMonth: 8,
      fastingDaysThisMonth: 10,
      activeFastStartedAt: nil
    )
  }
}
