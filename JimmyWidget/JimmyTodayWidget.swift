//
//  JimmyTodayWidget.swift
//  JimmyWidget
//

import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry {
    TodayEntry(date: Date(), snapshot: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(TodayEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .placeholder))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let entry = TodayEntry(date: Date(), snapshot: WidgetSnapshot.load() ?? .placeholder)
    // The app reloads timelines after every mutation; this fallback refresh
    // at midnight rolls the "today" checkmarks over to the new day.
    let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
    completion(Timeline(entries: [entry], policy: .after(midnight)))
  }
}

struct HabitStatus: Identifiable {
  let id: String
  let icon: String
  let color: Color
  let doneToday: Bool
  let monthCount: Int
}

struct TodayWidgetView: View {
  @Environment(\.widgetFamily) private var family
  var entry: TodayEntry

  private var habits: [HabitStatus] {
    let snapshot = entry.snapshot
    // A snapshot generated on an earlier day must not show that day's
    // checkmarks as today's.
    let isToday = Calendar.current.isDateInToday(snapshot.day)
    return [
      HabitStatus(
        id: "gym", icon: "dumbbell.fill", color: .blue,
        doneToday: isToday && snapshot.didWorkout,
        monthCount: snapshot.workoutDaysThisMonth),
      HabitStatus(
        id: "drinks", icon: "wineglass", color: .green,
        doneToday: isToday && snapshot.didNotDrink,
        monthCount: snapshot.drinkFreeDaysThisMonth),
      HabitStatus(
        id: "sauna", icon: "thermometer.medium", color: .orange,
        doneToday: isToday && snapshot.didSauna,
        monthCount: snapshot.saunaDaysThisMonth),
      HabitStatus(
        id: "fasting", icon: "clock.arrow.circlepath", color: .indigo,
        doneToday: isToday && snapshot.didFast,
        monthCount: snapshot.fastingDaysThisMonth),
    ]
  }

  var body: some View {
    Group {
      switch family {
      case .systemMedium:
        mediumView
      default:
        smallView
      }
    }
    .containerBackground(.background, for: .widget)
  }

  private var smallView: some View {
    VStack(spacing: 10) {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        ForEach(habits) { habit in
          habitCircle(habit)
        }
      }
      if entry.snapshot.activeFastStartedAt != nil {
        fastingTimerLine
      }
    }
  }

  private var mediumView: some View {
    VStack(spacing: 12) {
      HStack(spacing: 0) {
        ForEach(habits) { habit in
          VStack(spacing: 6) {
            habitCircle(habit)
            Text("\(habit.monthCount) this month")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
        }
      }
      if entry.snapshot.activeFastStartedAt != nil {
        fastingTimerLine
      }
    }
  }

  private func habitCircle(_ habit: HabitStatus) -> some View {
    ZStack(alignment: .bottomTrailing) {
      Circle()
        .fill(habit.doneToday ? habit.color : habit.color.opacity(0.15))
        .frame(width: 40, height: 40)
        .overlay {
          Image(systemName: habit.icon)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(habit.doneToday ? .white : habit.color)
        }
      if habit.doneToday {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 13))
          .foregroundStyle(.white, .green)
      }
    }
  }

  private var fastingTimerLine: some View {
    HStack(spacing: 4) {
      Image(systemName: "timer")
        .font(.caption2)
        .foregroundStyle(.indigo)
      if let start = entry.snapshot.activeFastStartedAt {
        Text("Fasting ") .font(.caption2).foregroundStyle(.secondary)
          + Text(start, style: .timer).font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct JimmyTodayWidget: Widget {
  let kind: String = "JimmyTodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      TodayWidgetView(entry: entry)
    }
    .configurationDisplayName("Today's Habits")
    .description("See which habits you've checked off today.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
