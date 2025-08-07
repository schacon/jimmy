//
//  ContentView.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import Foundation
import HealthKit
import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable {
  case home = "home"
  case drinks = "drinks"
  case sauna = "sauna"
  case gym = "gym"
  case exercises = "exercises"
  case settings = "settings"
}

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var settings: [AppSettings]
  @State private var selectedTab: AppTab = .home

  private var appSettings: AppSettings {
    if let existingSettings = settings.first {
      return existingSettings
    } else {
      // Create default settings if none exist
      let newSettings = AppSettings()
      modelContext.insert(newSettings)
      try? modelContext.save()
      return newSettings
    }
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      if appSettings.showHomeTab {
        HomeView(selectedTab: $selectedTab)
          .tabItem {
            Image(systemName: "house.fill")
            Text("Home")
          }
          .tag(AppTab.home)
      }

      if appSettings.showDrinksTab {
        DrinksCalendarView()
          .tabItem {
            Image(systemName: "wineglass")
            Text("Drinks")
          }
          .tag(AppTab.drinks)
      }

      if appSettings.showSaunaTab {
        SaunaCalendarView()
          .tabItem {
            Image(systemName: "thermometer.medium")
            Text("Sauna")
          }
          .tag(AppTab.sauna)
      }

      if appSettings.showGymTab {
        WorkoutCalendarView()
          .tabItem {
            Image(systemName: "dumbbell.fill")
            Text("Gym")
          }
          .tag(AppTab.gym)
      }

      if appSettings.showExercisesTab {
        ExerciseTrackingView()
          .tabItem {
            Image(systemName: "list.bullet")
            Text("Exercises")
          }
          .tag(AppTab.exercises)
      }

      SettingsView()
        .tabItem {
          Image(systemName: "gear")
          Text("Settings")
        }
        .tag(AppTab.settings)
    }
    .onAppear {
      // Set initial tab to first available tab if home is disabled
      if !appSettings.showHomeTab {
        if appSettings.showDrinksTab {
          selectedTab = .drinks
        } else if appSettings.showSaunaTab {
          selectedTab = .sauna
        } else if appSettings.showGymTab {
          selectedTab = .gym
        } else if appSettings.showExercisesTab {
          selectedTab = .exercises
        } else {
          selectedTab = .settings
        }
      }
    }
  }
}

struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var settings: [AppSettings]
  @Query private var workouts: [Workout]
  @Query private var drinkDays: [DrinkDay]
  @Query private var saunaDays: [SaunaDay]
  @Query private var exerciseEntries: [ExerciseEntry]
  @Binding var selectedTab: AppTab
  @State private var healthKitManager = HealthKitManager()

  private var appSettings: AppSettings {
    if let existingSettings = settings.first {
      return existingSettings
    } else {
      let newSettings = AppSettings()
      modelContext.insert(newSettings)
      try? modelContext.save()
      return newSettings
    }
  }

  private let calendar = Calendar.current

  private var last4WeeksRange: ClosedRange<Date> {
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -28, to: endDate) ?? endDate
    return startDate...endDate
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          VStack(spacing: 16) {

            // Overview Cards
            VStack(spacing: 12) {

              if appSettings.showDrinksTab {
                OverviewCard(
                  title: "Drinks",
                  subtitle: "Alcohol-free days",
                  icon: "wineglass",
                  color: .green,
                  percentage: drinkFreePercentage,
                  count: drinkFreeDaysCount,
                  total: totalDaysInRange,
                  action: {
                    selectedTab = .drinks
                  }
                )
              }

              if appSettings.showSaunaTab {
                OverviewCard(
                  title: "Sauna",
                  subtitle: "Sauna sessions",
                  icon: "thermometer.medium",
                  color: .orange,
                  percentage: saunaPercentage,
                  count: saunaDaysCount,
                  total: totalDaysInRange,
                  action: {
                    selectedTab = .sauna
                  }
                )
              }

              if appSettings.showGymTab {
                OverviewCard(
                  title: "Gym",
                  subtitle: "Workout days",
                  icon: "dumbbell.fill",
                  color: .blue,
                  percentage: workoutPercentage,
                  count: workoutDaysCount,
                  total: totalDaysInRange,
                  action: {
                    selectedTab = .gym
                  }
                )
              }

            }
            .padding(.horizontal)

            // HealthKit Data Section
            HStack {

              Spacer()

              if !healthKitManager.isAuthorized {
                Button("Enable") {
                  Task {
                    await healthKitManager.requestPermissions()
                  }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
              }
            }
            .padding(.horizontal)

            if healthKitManager.isAuthorized {
              VStack(spacing: 12) {
                // Weight Card
                HealthDataCard(
                  title: "Weight",
                  value: healthKitManager.weeklyAverageWeight > 0
                    ? String(format: "%.1f kg", healthKitManager.weeklyAverageWeight) : "--",
                  subtitle: healthKitManager.lastWeekAverageWeight > 0
                    ? String(
                      format: "This week • Last week: %.1f kg",
                      healthKitManager.lastWeekAverageWeight)
                    : "Weekly average",
                  icon: "scalemass",
                  color: .pink,
                  data: healthKitManager.weightData
                )

                // Steps Card
                HealthDataCard(
                  title: "Steps",
                  value: healthKitManager.weeklyAverageSteps > 0
                    ? "\(Int(healthKitManager.weeklyAverageSteps))" : "--",
                  subtitle: "Daily average",
                  icon: "figure.walk",
                  color: .teal,
                  data: healthKitManager.stepsData
                )
              }
              .padding(.horizontal)
            } else {
              VStack(spacing: 12) {
                Image(systemName: "heart.text.square")
                  .font(.system(size: 48))
                  .foregroundColor(.gray)

                Text("Connect to Apple Health")
                  .font(.headline)
                  .foregroundColor(.secondary)

                Text("View your weight and steps data alongside your habit tracking")
                  .font(.body)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
                  .padding(.horizontal)
              }
              .padding(.vertical, 20)
            }
          }
          Spacer(minLength: 40)
        }
        .padding(.top)
      }
      .onAppear {
        if healthKitManager.isAuthorized {
          Task {
            await healthKitManager.fetchHealthData()
          }
        }
      }
      .refreshable {
        if healthKitManager.isAuthorized {
          await healthKitManager.fetchHealthData()
        }
      }
    }
  }

  // MARK: - Computed Properties for Stats

  private var totalDaysInRange: Int {
    calendar.dateComponents(
      [.day], from: last4WeeksRange.lowerBound, to: last4WeeksRange.upperBound
    ).day ?? 28
  }

  private var drinkFreeDaysCount: Int {
    drinkDays.filter { day in
      last4WeeksRange.contains(day.date) && day.didNotDrink
    }.count
  }

  private var drinkFreePercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(drinkFreeDaysCount) / Double(totalDaysInRange) * 100
  }

  private var saunaDaysCount: Int {
    saunaDays.filter { day in
      last4WeeksRange.contains(day.date) && day.didSauna
    }.count
  }

  private var saunaPercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(saunaDaysCount) / Double(totalDaysInRange) * 100
  }

  private var workoutDaysCount: Int {
    workouts.filter { workout in
      last4WeeksRange.contains(workout.date) && workout.didWorkout
    }.count
  }

  private var workoutPercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(workoutDaysCount) / Double(totalDaysInRange) * 100
  }

}

struct OverviewCard: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  let percentage: Double
  let count: Int
  let total: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        // Icon
        Image(systemName: icon)
          .font(.title)
          .foregroundColor(color)
          .frame(width: 40, height: 40)

        // Content
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)

          Text(subtitle)
            .font(.subheadline)
            .foregroundColor(.secondary)

          // Progress Bar
          ProgressView(value: percentage / 100)
            .progressViewStyle(LinearProgressViewStyle(tint: color))
            .frame(height: 6)
        }

        Spacer()

        // Stats
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(Int(percentage))%")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(color)

          Text("\(count)/\(total) days")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(color.opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

struct WorkoutCalendarView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var workouts: [Workout]
  @State private var currentDate = Date()

  private let calendar = Calendar.current
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }()

  var body: some View {
    VStack(spacing: 20) {
      // Month and Year
      Text(dateFormatter.string(from: currentDate))
        .font(.title2)
        .fontWeight(.semibold)
        .padding(.top)

      // Stats boxes
      HStack(spacing: 12) {
        StatsBox(
          title: "Last 6 Months",
          workouts: workouts,
          dateRange: last6MonthsRange,
          isCurrentMonth: false
        )

        StatsBox(
          title: "This Month",
          workouts: workouts,
          dateRange: currentMonthRange,
          isCurrentMonth: true
        )
      }
      .padding(.horizontal)

      // Calendar Grid
      CalendarView(
        currentDate: currentDate,
        workouts: workouts,
        onDateTap: { date in
          toggleWorkout(for: date)
        }
      )
      .padding(.horizontal)

      Spacer()

      // Navigation buttons
      HStack(spacing: 40) {
        Button(action: previousMonth) {
          HStack {
            Image(systemName: "chevron.left")
            Text("Previous")
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }

        Button(action: nextMonth) {
          HStack {
            Text("Next")
            Image(systemName: "chevron.right")
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }
      }
      .padding(.bottom, 40)
    }
    .background(Color(.systemBackground))
    .onAppear {
      exportWorkoutsToJSON()
    }
  }

  private func previousMonth() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
    }
  }

  private func nextMonth() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
    }
  }

  private func toggleWorkout(for date: Date) {
    let startOfDay = calendar.startOfDay(for: date)

    // Don't allow future dates
    if startOfDay > calendar.startOfDay(for: Date()) {
      return
    }

    if let existingWorkout = workouts.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      // If workout exists, delete it (revert to no data)
      modelContext.delete(existingWorkout)
    } else {
      // Create new workout entry
      let newWorkout = Workout(date: startOfDay, didWorkout: true)
      modelContext.insert(newWorkout)
    }

    try? modelContext.save()

    // Export to JSON after data changes
    exportWorkoutsToJSON()
  }

  private func exportWorkoutsToJSON() {
    Task {
      await saveWorkoutsToiCloudDrive()
    }
  }

  private func saveWorkoutsToiCloudDrive() async {
    guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      print("iCloud Drive not available - enable it in Xcode Capabilities")
      return
    }

    // Create Jimmy folder in iCloud Drive
    let jimmyFolderURL = iCloudURL.appendingPathComponent("Documents/Jimmy")
    let workoutsFileURL = jimmyFolderURL.appendingPathComponent("workouts.json")

    do {
      // Create directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: jimmyFolderURL, withIntermediateDirectories: true, attributes: nil)

      // Convert workouts to JSON format
      let workoutDates = workouts.filter { $0.didWorkout }.map { workout in
        WorkoutExport(date: workout.date, didWorkout: workout.didWorkout)
      }

      let exportData = WorkoutExportContainer(
        exportDate: Date(),
        totalWorkouts: workoutDates.count,
        workouts: workoutDates
      )

      // Encode to JSON
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted

      let jsonData = try encoder.encode(exportData)

      // Write to iCloud Drive
      try jsonData.write(to: workoutsFileURL)

      print("✅ Workouts exported to iCloud Drive: Jimmy/workouts.json")

    } catch {
      print("❌ Failed to export workouts to iCloud Drive: \(error)")
    }
  }

  private var last6MonthsRange: ClosedRange<Date> {
    let endDate = Date()
    let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate

    // Find the first date we have any workout data
    let firstWorkoutDate = workouts.map { $0.date }.min()

    // Use the later of: first workout date or 6 months ago
    let startDate = [firstWorkoutDate, sixMonthsAgo].compactMap { $0 }.max() ?? sixMonthsAgo

    return startDate...endDate
  }

  private var currentMonthRange: ClosedRange<Date> {
    let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
    let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
    return startOfMonth...endOfMonth
  }
}

struct CalendarView: View {
  let currentDate: Date
  let workouts: [Workout]
  let onDateTap: (Date) -> Void

  private let calendar = Calendar.current
  private let columns = Array(repeating: GridItem(.flexible()), count: 7)

  var body: some View {
    VStack(spacing: 10) {
      // Day headers
      HStack {
        ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
          Text(day)
            .font(.caption)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .foregroundColor(.secondary)
        }
        // Space for checkmark column
        Spacer()
          .frame(width: 20)
      }

      // Calendar grid with weekly checkmarks
      VStack(spacing: 8) {
        ForEach(Array(weekRows.enumerated()), id: \.offset) { weekIndex, weekDays in
          HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
              DayView(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: currentDate, toGranularity: .month),
                workoutStatus: workoutStatus(for: date),
                onTap: { onDateTap(date) }
              )
            }

            // Weekly checkmark
            if hasThreeWorkoutsInWeek(weekDays) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            } else {
              Spacer()
                .frame(width: 16)
            }
          }
        }
      }
    }
  }

  private var daysInMonth: [Date] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
      let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start
    else {
      return []
    }

    let firstDayWeekday = calendar.component(.weekday, from: firstOfMonth)
    let numberOfEmptyDays = firstDayWeekday - 1

    var days: [Date] = []

    // Add empty days from previous month
    for i in 0..<numberOfEmptyDays {
      if let day = calendar.date(byAdding: .day, value: -(numberOfEmptyDays - i), to: firstOfMonth)
      {
        days.append(day)
      }
    }

    // Add days of current month
    let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 0
    for i in 0..<numberOfDaysInMonth {
      if let day = calendar.date(byAdding: .day, value: i, to: firstOfMonth) {
        days.append(day)
      }
    }

    // Add days from next month to fill the grid
    let remainingDays = 42 - days.count  // 6 rows × 7 days
    let lastDayOfMonth = days.last ?? firstOfMonth
    for i in 1...remainingDays {
      if let day = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
        days.append(day)
      }
    }

    return days
  }

  private var weekRows: [[Date]] {
    let days = daysInMonth
    var weeks: [[Date]] = []

    for i in stride(from: 0, to: days.count, by: 7) {
      let weekEnd = min(i + 7, days.count)
      let week = Array(days[i..<weekEnd])
      weeks.append(week)
    }

    return weeks
  }

  private func hasThreeWorkoutsInWeek(_ weekDays: [Date]) -> Bool {
    let workoutCount = weekDays.reduce(0) { count, date in
      let startOfDay = calendar.startOfDay(for: date)
      if let workout = workouts.first(where: {
        calendar.isDate($0.date, inSameDayAs: startOfDay)
      }), workout.didWorkout {
        return count + 1
      }
      return count
    }
    return workoutCount >= 3
  }

  private func workoutStatus(for date: Date) -> WorkoutStatus {
    let startOfDay = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())

    if startOfDay > today {
      return .future
    }

    if let workout = workouts.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      return workout.didWorkout ? .worked : .didNotWork
    }

    return .noData
  }
}

struct DayView: View {
  let date: Date
  let isCurrentMonth: Bool
  let workoutStatus: WorkoutStatus
  let onTap: () -> Void

  private let calendar = Calendar.current

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        Text("\(calendar.component(.day, from: date))")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(textColor)

        Circle()
          .fill(indicatorColor)
          .frame(width: 6, height: 6)
          .opacity(indicatorOpacity)
      }
      .frame(width: 40, height: 50)
      .background(backgroundColor)
      .cornerRadius(8)
    }
    .disabled(workoutStatus == .future)
  }

  private var textColor: Color {
    if !isCurrentMonth {
      return .secondary
    }

    if workoutStatus == .future {
      return .secondary
    }

    return .primary
  }

  private var backgroundColor: Color {
    if workoutStatus == .future {
      return Color(.systemGray5)
    }

    switch workoutStatus {
    case .worked:
      return .blue.opacity(0.2)
    case .didNotWork:
      return .red.opacity(0.2)
    case .noData:
      return .clear
    case .future:
      return Color(.systemGray5)
    }
  }

  private var indicatorColor: Color {
    switch workoutStatus {
    case .worked:
      return .blue
    case .didNotWork:
      return .red
    case .noData:
      return .clear
    case .future:
      return .clear
    }
  }

  private var indicatorOpacity: Double {
    switch workoutStatus {
    case .worked, .didNotWork:
      return 1.0
    case .noData, .future:
      return 0.0
    }
  }
}

struct StatsBox: View {
  let title: String
  let workouts: [Workout]
  let dateRange: ClosedRange<Date>
  let isCurrentMonth: Bool

  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "calendar.badge.checkmark")
            .foregroundColor(.blue)
            .font(.caption)
          Text(
            "\(weeksWithThreePlusWorkouts)/\(isCurrentMonth ? elapsedWeeksInCurrentMonth : totalWeeksInRange) weeks"
          )
          .font(.caption2)
          .fontWeight(.medium)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text("\(Int(workoutPercentage))% days")
            .font(.title3)
            .fontWeight(.bold)

          Text("(\(workoutDaysCount)/\(totalDaysForCalculation))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        ProgressView(value: workoutPercentage / 100)
          .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
          .scaleEffect(y: 0.8)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private var workoutPercentage: Double {
    let relevantWorkouts = workouts.filter { workout in
      dateRange.contains(workout.date) && workout.didWorkout
    }

    let totalDays = isCurrentMonth ? daysSinceStartOfMonth : daysInRange
    guard totalDays > 0 else { return 0 }

    return Double(relevantWorkouts.count) / Double(totalDays) * 100
  }

  private var workoutDaysCount: Int {
    return workouts.filter { workout in
      dateRange.contains(workout.date) && workout.didWorkout
    }.count
  }

  private var totalDaysForCalculation: Int {
    return isCurrentMonth ? daysSinceStartOfMonth : daysInRange
  }

  private var weeksWithThreePlusWorkouts: Int {
    var weeklyWorkouts: [Int: Int] = [:]

    for workout in workouts {
      guard dateRange.contains(workout.date) && workout.didWorkout else { continue }

      let weekOfYear = calendar.component(.weekOfYear, from: workout.date)
      let year = calendar.component(.year, from: workout.date)
      let weekKey = year * 100 + weekOfYear

      weeklyWorkouts[weekKey, default: 0] += 1
    }

    return weeklyWorkouts.values.filter { $0 >= 3 }.count
  }

  private var totalWeeksInRange: Int {
    let startDate = dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())  // Don't count future weeks

    let weeksBetween =
      calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear ?? 0
    return max(1, weeksBetween + 1)  // +1 because we include partial weeks
  }

  private var elapsedWeeksInCurrentMonth: Int {
    guard let startOfMonth = calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.start,
      let endOfMonth = calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.end
    else {
      return 1
    }

    let today = Date()
    let endDate = min(endOfMonth, today)  // Don't count future weeks

    var validWeeks = 0
    var currentWeekStart = startOfMonth

    // Go through each week until we reach the end date
    while currentWeekStart < endDate {
      // Find the start of the current week
      let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeekStart)
      guard let weekStart = weekInterval?.start,
        let weekEnd = weekInterval?.end
      else {
        break
      }

      // Count days in this week that are in the current month and not in the future
      let weekStartInMonth = max(weekStart, startOfMonth)
      let weekEndInMonth = min(weekEnd, endOfMonth)
      let weekEndElapsed = min(weekEndInMonth, today)

      if weekStartInMonth < weekEndElapsed {
        let daysInWeek =
          calendar.dateComponents([.day], from: weekStartInMonth, to: weekEndElapsed).day ?? 0

        // Only count weeks with more than 4 days in the current month
        if daysInWeek > 4 {
          validWeeks += 1
        }
      }

      // Move to next week
      currentWeekStart =
        calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? endDate
    }

    return max(1, validWeeks)  // Always return at least 1
  }

  private var daysInRange: Int {
    let startDate = dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())  // Don't count future days
    return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
  }

  private var daysSinceStartOfMonth: Int {
    let startOfMonth =
      calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.start ?? dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())  // Don't count future days
    return calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0
  }

  private var progressColor: Color {
    if workoutPercentage >= 50 {
      return .green
    } else if workoutPercentage >= 40 {
      return .blue
    } else if workoutPercentage >= 20 {
      return .yellow
    } else {
      return .red
    }
  }
}

enum WorkoutStatus {
  case worked
  case didNotWork
  case noData
  case future
}

// MARK: - JSON Export Structures
struct WorkoutExport: Codable {
  let date: Date
  let didWorkout: Bool
}

struct WorkoutExportContainer: Codable {
  let exportDate: Date
  let totalWorkouts: Int
  let workouts: [WorkoutExport]
}

struct SaunaCalendarView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var saunaDays: [SaunaDay]
  @State private var currentDate = Date()

  private let calendar = Calendar.current
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }()

  var body: some View {
    VStack(spacing: 20) {
      // Month and Year
      Text(dateFormatter.string(from: currentDate))
        .font(.title2)
        .fontWeight(.semibold)
        .padding(.top)

      // Stats boxes
      HStack(spacing: 12) {
        SaunaStatsBox(
          title: "Last 6 Months",
          saunaDays: saunaDays,
          dateRange: last6MonthsRange,
          isCurrentMonth: false
        )

        SaunaStatsBox(
          title: "This Month",
          saunaDays: saunaDays,
          dateRange: currentMonthRange,
          isCurrentMonth: true
        )
      }
      .padding(.horizontal)

      // Calendar Grid
      SaunaCalendarGrid(
        currentDate: currentDate,
        saunaDays: saunaDays,
        onDateTap: { date in
          toggleSaunaDay(for: date)
        }
      )
      .padding(.horizontal)

      Spacer()

      // Navigation buttons
      HStack(spacing: 40) {
        Button(action: previousMonth) {
          HStack {
            Image(systemName: "chevron.left")
            Text("Previous")
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }

        Button(action: nextMonth) {
          HStack {
            Text("Next")
            Image(systemName: "chevron.right")
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }
      }
      .padding(.bottom, 40)
    }
    .background(Color(.systemBackground))
    .onAppear {
      exportSaunaDaysToJSON()
    }
  }

  private func previousMonth() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
    }
  }

  private func nextMonth() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
    }
  }

  private func toggleSaunaDay(for date: Date) {
    let startOfDay = calendar.startOfDay(for: date)

    // Don't allow future dates
    if startOfDay > calendar.startOfDay(for: Date()) {
      return
    }

    if let existingSaunaDay = saunaDays.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      // If sauna day exists, delete it (revert to no data)
      modelContext.delete(existingSaunaDay)
    } else {
      // Create new sauna day entry
      let newSaunaDay = SaunaDay(date: startOfDay, didSauna: true)
      modelContext.insert(newSaunaDay)
    }

    try? modelContext.save()

    // Export to JSON after data changes
    exportSaunaDaysToJSON()
  }

  private func exportSaunaDaysToJSON() {
    Task {
      await saveSaunaDaysToiCloudDrive()
    }
  }

  private func saveSaunaDaysToiCloudDrive() async {
    guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      print("iCloud Drive not available - enable it in Xcode Capabilities")
      return
    }

    // Create Jimmy folder in iCloud Drive
    let jimmyFolderURL = iCloudURL.appendingPathComponent("Documents/Jimmy")
    let saunaDaysFileURL = jimmyFolderURL.appendingPathComponent("saunadays.json")

    do {
      // Create directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: jimmyFolderURL, withIntermediateDirectories: true, attributes: nil)

      // Convert sauna days to JSON format
      let saunaDates = saunaDays.filter { $0.didSauna }.map { saunaDay in
        SaunaDayExport(date: saunaDay.date, didSauna: saunaDay.didSauna)
      }

      let exportData = SaunaDayExportContainer(
        exportDate: Date(),
        totalSaunaDays: saunaDates.count,
        saunaDays: saunaDates
      )

      // Encode to JSON
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted

      let jsonData = try encoder.encode(exportData)

      // Write to iCloud Drive
      try jsonData.write(to: saunaDaysFileURL)

      print("✅ Sauna days exported to iCloud Drive: Jimmy/saunadays.json")

    } catch {
      print("❌ Failed to export sauna days to iCloud Drive: \(error)")
    }
  }

  private var last6MonthsRange: ClosedRange<Date> {
    let endDate = Date()
    let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate

    // Find the first date we have any sauna day data
    let firstSaunaDayDate = saunaDays.map { $0.date }.min()

    // Use the later of: first sauna day date or 6 months ago
    let startDate = [firstSaunaDayDate, sixMonthsAgo].compactMap { $0 }.max() ?? sixMonthsAgo

    return startDate...endDate
  }

  private var currentMonthRange: ClosedRange<Date> {
    let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
    let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
    return startOfMonth...endOfMonth
  }
}

struct DrinksCalendarView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var drinkDays: [DrinkDay]
  @State private var currentDate = Date()

  private let calendar = Calendar.current
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
  }()

  var body: some View {
    VStack(spacing: 20) {
      // Month and Year
      Text(dateFormatter.string(from: currentDate))
        .font(.title2)
        .fontWeight(.semibold)
        .padding(.top)

      // Stats boxes
      HStack(spacing: 12) {
        DrinksStatsBox(
          title: "Last 6 Months",
          drinkDays: drinkDays,
          dateRange: last6MonthsRange,
          isCurrentMonth: false
        )

        DrinksStatsBox(
          title: "This Month",
          drinkDays: drinkDays,
          dateRange: currentMonthRange,
          isCurrentMonth: true
        )
      }
      .padding(.horizontal)

      // Calendar Grid
      DrinksCalendarGrid(
        currentDate: currentDate,
        drinkDays: drinkDays,
        onDateTap: { date in
          toggleDrinkDay(for: date)
        }
      )
      .padding(.horizontal)

      Spacer()

      // Navigation buttons
      HStack(spacing: 40) {
        Button(action: previousMonth) {
          HStack {
            Image(systemName: "chevron.left")
            Text("Previous")
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }

        Button(action: nextMonth) {
          HStack {
            Text("Next")
            Image(systemName: "chevron.right")
          }
          .foregroundColor(.blue)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }
      }
      .padding(.bottom, 40)
    }
    .background(Color(.systemBackground))
    .onAppear {
      exportDrinkDaysToJSON()
    }
  }

  private func previousMonth() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
    }
  }

  private func nextMonth() {
    withAnimation(.easeInOut(duration: 0.3)) {
      currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
    }
  }

  private func toggleDrinkDay(for date: Date) {
    let startOfDay = calendar.startOfDay(for: date)

    // Don't allow future dates
    if startOfDay > calendar.startOfDay(for: Date()) {
      return
    }

    if let existingDrinkDay = drinkDays.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      // If drink day exists, delete it (revert to no data)
      modelContext.delete(existingDrinkDay)
    } else {
      // Create new drink-free day entry
      let newDrinkDay = DrinkDay(date: startOfDay, didNotDrink: true)
      modelContext.insert(newDrinkDay)
    }

    try? modelContext.save()

    // Export to JSON after data changes
    exportDrinkDaysToJSON()
  }

  private func exportDrinkDaysToJSON() {
    Task {
      await saveDrinkDaysToiCloudDrive()
    }
  }

  private func saveDrinkDaysToiCloudDrive() async {
    guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      print("iCloud Drive not available - enable it in Xcode Capabilities")
      return
    }

    // Create Jimmy folder in iCloud Drive
    let jimmyFolderURL = iCloudURL.appendingPathComponent("Documents/Jimmy")
    let drinkDaysFileURL = jimmyFolderURL.appendingPathComponent("drinkdays.json")

    do {
      // Create directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: jimmyFolderURL, withIntermediateDirectories: true, attributes: nil)

      // Convert drink days to JSON format
      let drinkFreeDates = drinkDays.filter { $0.didNotDrink }.map { drinkDay in
        DrinkDayExport(date: drinkDay.date, didNotDrink: drinkDay.didNotDrink)
      }

      let exportData = DrinkDayExportContainer(
        exportDate: Date(),
        totalDrinkFreeDays: drinkFreeDates.count,
        drinkDays: drinkFreeDates
      )

      // Encode to JSON
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted

      let jsonData = try encoder.encode(exportData)

      // Write to iCloud Drive
      try jsonData.write(to: drinkDaysFileURL)

      print("✅ Drink days exported to iCloud Drive: Jimmy/drinkdays.json")

    } catch {
      print("❌ Failed to export drink days to iCloud Drive: \(error)")
    }
  }

  private var last6MonthsRange: ClosedRange<Date> {
    let endDate = Date()
    let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate

    // Find the first date we have any drink day data
    let firstDrinkDayDate = drinkDays.map { $0.date }.min()

    // Use the later of: first drink day date or 6 months ago
    let startDate = [firstDrinkDayDate, sixMonthsAgo].compactMap { $0 }.max() ?? sixMonthsAgo

    return startDate...endDate
  }

  private var currentMonthRange: ClosedRange<Date> {
    let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
    let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
    return startOfMonth...endOfMonth
  }
}

struct DrinksCalendarGrid: View {
  let currentDate: Date
  let drinkDays: [DrinkDay]
  let onDateTap: (Date) -> Void

  private let calendar = Calendar.current
  private let columns = Array(repeating: GridItem(.flexible()), count: 7)

  var body: some View {
    VStack(spacing: 10) {
      // Day headers
      HStack {
        ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
          Text(day)
            .font(.caption)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .foregroundColor(.secondary)
        }
        // Space for checkmark column
        Spacer()
          .frame(width: 20)
      }

      // Calendar grid with weekly checkmarks
      VStack(spacing: 8) {
        ForEach(Array(weekRows.enumerated()), id: \.offset) { weekIndex, weekDays in
          HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
              DrinkDayView(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: currentDate, toGranularity: .month),
                drinkStatus: drinkStatus(for: date),
                onTap: { onDateTap(date) }
              )
            }

            // Weekly checkmark for 5+ drink-free days
            if hasFiveDrinkFreeDaysInWeek(weekDays) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            } else {
              Spacer()
                .frame(width: 16)
            }
          }
        }
      }
    }
  }

  private var daysInMonth: [Date] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
      let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start
    else {
      return []
    }

    let firstDayWeekday = calendar.component(.weekday, from: firstOfMonth)
    let numberOfEmptyDays = firstDayWeekday - 1

    var days: [Date] = []

    // Add empty days from previous month
    for i in 0..<numberOfEmptyDays {
      if let day = calendar.date(byAdding: .day, value: -(numberOfEmptyDays - i), to: firstOfMonth)
      {
        days.append(day)
      }
    }

    // Add days of current month
    let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 0
    for i in 0..<numberOfDaysInMonth {
      if let day = calendar.date(byAdding: .day, value: i, to: firstOfMonth) {
        days.append(day)
      }
    }

    // Add days from next month to fill the grid
    let remainingDays = 42 - days.count  // 6 rows × 7 days
    let lastDayOfMonth = days.last ?? firstOfMonth
    for i in 1...remainingDays {
      if let day = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
        days.append(day)
      }
    }

    return days
  }

  private var weekRows: [[Date]] {
    let days = daysInMonth
    var weeks: [[Date]] = []

    for i in stride(from: 0, to: days.count, by: 7) {
      let weekEnd = min(i + 7, days.count)
      let week = Array(days[i..<weekEnd])
      weeks.append(week)
    }

    return weeks
  }

  private func hasFiveDrinkFreeDaysInWeek(_ weekDays: [Date]) -> Bool {
    let drinkFreeCount = weekDays.reduce(0) { count, date in
      let startOfDay = calendar.startOfDay(for: date)
      if let drinkDay = drinkDays.first(where: {
        calendar.isDate($0.date, inSameDayAs: startOfDay)
      }), drinkDay.didNotDrink {
        return count + 1
      }
      return count
    }
    return drinkFreeCount >= 5
  }

  private func drinkStatus(for date: Date) -> DrinkStatus {
    let startOfDay = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())

    if startOfDay > today {
      return .future
    }

    if let drinkDay = drinkDays.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      return drinkDay.didNotDrink ? .didNotDrink : .drank
    }

    return .noData
  }
}

struct DrinkDayView: View {
  let date: Date
  let isCurrentMonth: Bool
  let drinkStatus: DrinkStatus
  let onTap: () -> Void

  private let calendar = Calendar.current

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        Text("\(calendar.component(.day, from: date))")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(textColor)

        Circle()
          .fill(indicatorColor)
          .frame(width: 6, height: 6)
          .opacity(indicatorOpacity)
      }
      .frame(width: 40, height: 50)
      .background(backgroundColor)
      .cornerRadius(8)
    }
    .disabled(drinkStatus == .future)
  }

  private var textColor: Color {
    if !isCurrentMonth {
      return .secondary
    }

    if drinkStatus == .future {
      return .secondary
    }

    return .primary
  }

  private var backgroundColor: Color {
    if drinkStatus == .future {
      return Color(.systemGray5)
    }

    switch drinkStatus {
    case .didNotDrink:
      return .green.opacity(0.2)
    case .drank:
      return .red.opacity(0.2)
    case .noData:
      return .clear
    case .future:
      return Color(.systemGray5)
    }
  }

  private var indicatorColor: Color {
    switch drinkStatus {
    case .didNotDrink:
      return .green
    case .drank:
      return .red
    case .noData:
      return .clear
    case .future:
      return .clear
    }
  }

  private var indicatorOpacity: Double {
    switch drinkStatus {
    case .didNotDrink, .drank:
      return 1.0
    case .noData, .future:
      return 0.0
    }
  }
}

struct DrinksStatsBox: View {
  let title: String
  let drinkDays: [DrinkDay]
  let dateRange: ClosedRange<Date>
  let isCurrentMonth: Bool

  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "checkmark.circle")
            .foregroundColor(.green)
            .font(.caption)
          Text(
            "\(weeksWithFivePlusDrinkFreeDays)/\(isCurrentMonth ? elapsedWeeksInCurrentMonth : totalWeeksInRange) weeks"
          )
          .font(.caption2)
          .fontWeight(.medium)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text("\(Int(drinkFreePercentage))% days")
            .font(.title3)
            .fontWeight(.bold)

          Text("(\(drinkFreeDaysCount)/\(totalDaysForCalculation))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        ProgressView(value: drinkFreePercentage / 100)
          .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
          .scaleEffect(y: 0.8)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private var drinkFreePercentage: Double {
    let relevantDrinkDays = drinkDays.filter { drinkDay in
      dateRange.contains(drinkDay.date) && drinkDay.didNotDrink
    }

    let totalDays = isCurrentMonth ? daysSinceStartOfMonth : daysInRange
    guard totalDays > 0 else { return 0 }

    return Double(relevantDrinkDays.count) / Double(totalDays) * 100
  }

  private var drinkFreeDaysCount: Int {
    return drinkDays.filter { drinkDay in
      dateRange.contains(drinkDay.date) && drinkDay.didNotDrink
    }.count
  }

  private var totalDaysForCalculation: Int {
    return isCurrentMonth ? daysSinceStartOfMonth : daysInRange
  }

  private var weeksWithFivePlusDrinkFreeDays: Int {
    var weeklyDrinkFreeDays: [Int: Int] = [:]

    for drinkDay in drinkDays {
      guard dateRange.contains(drinkDay.date) && drinkDay.didNotDrink else { continue }

      let weekOfYear = calendar.component(.weekOfYear, from: drinkDay.date)
      let year = calendar.component(.year, from: drinkDay.date)
      let weekKey = year * 100 + weekOfYear

      weeklyDrinkFreeDays[weekKey, default: 0] += 1
    }

    return weeklyDrinkFreeDays.values.filter { $0 >= 5 }.count
  }

  private var totalWeeksInRange: Int {
    let startDate = dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())

    let weeksBetween =
      calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear ?? 0
    return max(1, weeksBetween + 1)
  }

  private var elapsedWeeksInCurrentMonth: Int {
    guard let startOfMonth = calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.start,
      let endOfMonth = calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.end
    else {
      return 1
    }

    let today = Date()
    let endDate = min(endOfMonth, today)

    var validWeeks = 0
    var currentWeekStart = startOfMonth

    while currentWeekStart < endDate {
      let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeekStart)
      guard let weekStart = weekInterval?.start,
        let weekEnd = weekInterval?.end
      else {
        break
      }

      let weekStartInMonth = max(weekStart, startOfMonth)
      let weekEndInMonth = min(weekEnd, endOfMonth)
      let weekEndElapsed = min(weekEndInMonth, today)

      if weekStartInMonth < weekEndElapsed {
        let daysInWeek =
          calendar.dateComponents([.day], from: weekStartInMonth, to: weekEndElapsed).day ?? 0

        if daysInWeek > 4 {
          validWeeks += 1
        }
      }

      currentWeekStart =
        calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? endDate
    }

    return max(1, validWeeks)
  }

  private var daysInRange: Int {
    let startDate = dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())
    return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
  }

  private var daysSinceStartOfMonth: Int {
    let startOfMonth =
      calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.start ?? dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())
    return calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0
  }

  private var progressColor: Color {
    if drinkFreePercentage >= 80 {
      return .green
    } else if drinkFreePercentage >= 60 {
      return .blue
    } else if drinkFreePercentage >= 40 {
      return .yellow
    } else {
      return .red
    }
  }
}

enum DrinkStatus {
  case didNotDrink
  case drank
  case noData
  case future
}

// MARK: - JSON Export Structures for Drinks
struct DrinkDayExport: Codable {
  let date: Date
  let didNotDrink: Bool
}

struct DrinkDayExportContainer: Codable {
  let exportDate: Date
  let totalDrinkFreeDays: Int
  let drinkDays: [DrinkDayExport]
}

struct SaunaCalendarGrid: View {
  let currentDate: Date
  let saunaDays: [SaunaDay]
  let onDateTap: (Date) -> Void

  private let calendar = Calendar.current
  private let columns = Array(repeating: GridItem(.flexible()), count: 7)

  var body: some View {
    VStack(spacing: 10) {
      // Day headers
      HStack {
        ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
          Text(day)
            .font(.caption)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .foregroundColor(.secondary)
        }
        // Space for checkmark column
        Spacer()
          .frame(width: 20)
      }

      // Calendar grid with weekly checkmarks
      VStack(spacing: 8) {
        ForEach(Array(weekRows.enumerated()), id: \.offset) { weekIndex, weekDays in
          HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
              SaunaDayView(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: currentDate, toGranularity: .month),
                saunaStatus: saunaStatus(for: date),
                onTap: { onDateTap(date) }
              )
            }

            // Weekly checkmark for 3+ sauna days
            if hasThreeSaunaDaysInWeek(weekDays) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            } else {
              Spacer()
                .frame(width: 16)
            }
          }
        }
      }
    }
  }

  private var daysInMonth: [Date] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
      let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start
    else {
      return []
    }

    let firstDayWeekday = calendar.component(.weekday, from: firstOfMonth)
    let numberOfEmptyDays = firstDayWeekday - 1

    var days: [Date] = []

    // Add empty days from previous month
    for i in 0..<numberOfEmptyDays {
      if let day = calendar.date(byAdding: .day, value: -(numberOfEmptyDays - i), to: firstOfMonth)
      {
        days.append(day)
      }
    }

    // Add days of current month
    let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 0
    for i in 0..<numberOfDaysInMonth {
      if let day = calendar.date(byAdding: .day, value: i, to: firstOfMonth) {
        days.append(day)
      }
    }

    // Add days from next month to fill the grid
    let remainingDays = 42 - days.count  // 6 rows × 7 days
    let lastDayOfMonth = days.last ?? firstOfMonth
    for i in 1...remainingDays {
      if let day = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
        days.append(day)
      }
    }

    return days
  }

  private var weekRows: [[Date]] {
    let days = daysInMonth
    var weeks: [[Date]] = []

    for i in stride(from: 0, to: days.count, by: 7) {
      let weekEnd = min(i + 7, days.count)
      let week = Array(days[i..<weekEnd])
      weeks.append(week)
    }

    return weeks
  }

  private func hasThreeSaunaDaysInWeek(_ weekDays: [Date]) -> Bool {
    let saunaCount = weekDays.reduce(0) { count, date in
      let startOfDay = calendar.startOfDay(for: date)
      if let saunaDay = saunaDays.first(where: {
        calendar.isDate($0.date, inSameDayAs: startOfDay)
      }), saunaDay.didSauna {
        return count + 1
      }
      return count
    }
    return saunaCount >= 3
  }

  private func saunaStatus(for date: Date) -> SaunaStatus {
    let startOfDay = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())

    if startOfDay > today {
      return .future
    }

    if let saunaDay = saunaDays.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      return saunaDay.didSauna ? .didSauna : .didNotSauna
    }

    return .noData
  }
}

struct SaunaDayView: View {
  let date: Date
  let isCurrentMonth: Bool
  let saunaStatus: SaunaStatus
  let onTap: () -> Void

  private let calendar = Calendar.current

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        Text("\(calendar.component(.day, from: date))")
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(textColor)

        Circle()
          .fill(indicatorColor)
          .frame(width: 6, height: 6)
          .opacity(indicatorOpacity)
      }
      .frame(width: 40, height: 50)
      .background(backgroundColor)
      .cornerRadius(8)
    }
    .disabled(saunaStatus == .future)
  }

  private var textColor: Color {
    if !isCurrentMonth {
      return .secondary
    }

    if saunaStatus == .future {
      return .secondary
    }

    return .primary
  }

  private var backgroundColor: Color {
    if saunaStatus == .future {
      return Color(.systemGray5)
    }

    switch saunaStatus {
    case .didSauna:
      return .orange.opacity(0.2)
    case .didNotSauna:
      return .gray.opacity(0.2)
    case .noData:
      return .clear
    case .future:
      return Color(.systemGray5)
    }
  }

  private var indicatorColor: Color {
    switch saunaStatus {
    case .didSauna:
      return .orange
    case .didNotSauna:
      return .gray
    case .noData:
      return .clear
    case .future:
      return .clear
    }
  }

  private var indicatorOpacity: Double {
    switch saunaStatus {
    case .didSauna, .didNotSauna:
      return 1.0
    case .noData, .future:
      return 0.0
    }
  }
}

struct SaunaStatsBox: View {
  let title: String
  let saunaDays: [SaunaDay]
  let dateRange: ClosedRange<Date>
  let isCurrentMonth: Bool

  private let calendar = Calendar.current

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: "thermometer.medium")
            .foregroundColor(.orange)
            .font(.caption)
          Text(
            "\(weeksWithThreePlusSaunaDays)/\(isCurrentMonth ? elapsedWeeksInCurrentMonth : totalWeeksInRange) weeks"
          )
          .font(.caption2)
          .fontWeight(.medium)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text("\(Int(saunaPercentage))% days")
            .font(.title3)
            .fontWeight(.bold)

          Text("(\(saunaDaysCount)/\(totalDaysForCalculation))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        ProgressView(value: saunaPercentage / 100)
          .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
          .scaleEffect(y: 0.8)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private var saunaPercentage: Double {
    let relevantSaunaDays = saunaDays.filter { saunaDay in
      dateRange.contains(saunaDay.date) && saunaDay.didSauna
    }

    let totalDays = isCurrentMonth ? daysSinceStartOfMonth : daysInRange
    guard totalDays > 0 else { return 0 }

    return Double(relevantSaunaDays.count) / Double(totalDays) * 100
  }

  private var saunaDaysCount: Int {
    return saunaDays.filter { saunaDay in
      dateRange.contains(saunaDay.date) && saunaDay.didSauna
    }.count
  }

  private var totalDaysForCalculation: Int {
    return isCurrentMonth ? daysSinceStartOfMonth : daysInRange
  }

  private var weeksWithThreePlusSaunaDays: Int {
    var weeklySaunaDays: [Int: Int] = [:]

    for saunaDay in saunaDays {
      guard dateRange.contains(saunaDay.date) && saunaDay.didSauna else { continue }

      let weekOfYear = calendar.component(.weekOfYear, from: saunaDay.date)
      let year = calendar.component(.year, from: saunaDay.date)
      let weekKey = year * 100 + weekOfYear

      weeklySaunaDays[weekKey, default: 0] += 1
    }

    return weeklySaunaDays.values.filter { $0 >= 3 }.count
  }

  private var totalWeeksInRange: Int {
    let startDate = dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())

    let weeksBetween =
      calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear ?? 0
    return max(1, weeksBetween + 1)
  }

  private var elapsedWeeksInCurrentMonth: Int {
    guard let startOfMonth = calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.start,
      let endOfMonth = calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.end
    else {
      return 1
    }

    let today = Date()
    let endDate = min(endOfMonth, today)

    var validWeeks = 0
    var currentWeekStart = startOfMonth

    while currentWeekStart < endDate {
      let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeekStart)
      guard let weekStart = weekInterval?.start,
        let weekEnd = weekInterval?.end
      else {
        break
      }

      let weekStartInMonth = max(weekStart, startOfMonth)
      let weekEndInMonth = min(weekEnd, endOfMonth)
      let weekEndElapsed = min(weekEndInMonth, today)

      if weekStartInMonth < weekEndElapsed {
        let daysInWeek =
          calendar.dateComponents([.day], from: weekStartInMonth, to: weekEndElapsed).day ?? 0

        if daysInWeek > 4 {
          validWeeks += 1
        }
      }

      currentWeekStart =
        calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? endDate
    }

    return max(1, validWeeks)
  }

  private var daysInRange: Int {
    let startDate = dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())
    return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
  }

  private var daysSinceStartOfMonth: Int {
    let startOfMonth =
      calendar.dateInterval(of: .month, for: dateRange.lowerBound)?.start ?? dateRange.lowerBound
    let endDate = min(dateRange.upperBound, Date())
    return calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0
  }

  private var progressColor: Color {
    if saunaPercentage >= 50 {
      return .orange
    } else if saunaPercentage >= 30 {
      return .blue
    } else if saunaPercentage >= 15 {
      return .yellow
    } else {
      return .red
    }
  }
}

enum SaunaStatus {
  case didSauna
  case didNotSauna
  case noData
  case future
}

// MARK: - JSON Export Structures for Sauna
struct SaunaDayExport: Codable {
  let date: Date
  let didSauna: Bool
}

struct SaunaDayExportContainer: Codable {
  let exportDate: Date
  let totalSaunaDays: Int
  let saunaDays: [SaunaDayExport]
}

struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var settings: [AppSettings]
  @Query private var workouts: [Workout]
  @Query private var drinkDays: [DrinkDay]
  @Query private var saunaDays: [SaunaDay]
  @Query private var exercises: [Exercise]
  @Query private var exerciseEntries: [ExerciseEntry]
  @State private var showingShareSheet = false
  @State private var shareURL: URL?

  private var appSettings: AppSettings {
    if let existingSettings = settings.first {
      return existingSettings
    } else {
      // Create default settings if none exist
      let newSettings = AppSettings()
      modelContext.insert(newSettings)
      try? modelContext.save()
      return newSettings
    }
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Visible Tabs")) {
          Toggle(
            isOn: Binding(
              get: { appSettings.showHomeTab },
              set: { newValue in
                appSettings.showHomeTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "house.fill")
                .foregroundColor(.blue)
                .frame(width: 20)
              Text("Home")
            }
          }

          Toggle(
            isOn: Binding(
              get: { appSettings.showDrinksTab },
              set: { newValue in
                appSettings.showDrinksTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "wineglass")
                .foregroundColor(.green)
                .frame(width: 20)
              Text("Drinks")
            }
          }

          Toggle(
            isOn: Binding(
              get: { appSettings.showSaunaTab },
              set: { newValue in
                appSettings.showSaunaTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "thermometer.medium")
                .foregroundColor(.orange)
                .frame(width: 20)
              Text("Sauna")
            }
          }

          Toggle(
            isOn: Binding(
              get: { appSettings.showGymTab },
              set: { newValue in
                appSettings.showGymTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "dumbbell.fill")
                .foregroundColor(.blue)
                .frame(width: 20)
              Text("Gym")
            }
          }

          Toggle(
            isOn: Binding(
              get: { appSettings.showExercisesTab },
              set: { newValue in
                appSettings.showExercisesTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "list.bullet")
                .foregroundColor(.purple)
                .frame(width: 20)
              Text("Exercises")
            }
          }
        }

        Section(header: Text("About")) {
          HStack {
            Text("App Version")
            Spacer()
            Text("1.0.0")
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Data Storage")
            Spacer()
            Text("iCloud + Local")
              .foregroundColor(.secondary)
          }
        }

        Section(header: Text("Data")) {
          Button(action: {
            exportAllData()
          }) {
            HStack {
              Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
              Text("Export Data")
            }
          }
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .sheet(isPresented: $showingShareSheet) {
        if let shareURL = shareURL {
          ShareSheet(activityItems: [shareURL])
        }
      }
    }
  }

  private func exportAllData() {
    Task {
      do {
        let exportData = ComprehensiveExport(
          exportDate: Date(),
          appVersion: "1.0.0",
          settings: ComprehensiveExport.SettingsExport(
            showHomeTab: appSettings.showHomeTab,
            showDrinksTab: appSettings.showDrinksTab,
            showSaunaTab: appSettings.showSaunaTab,
            showGymTab: appSettings.showGymTab,
            showExercisesTab: appSettings.showExercisesTab
          ),
          workouts: workouts.map { workout in
            ComprehensiveExport.WorkoutExport(
              date: workout.date,
              didWorkout: workout.didWorkout
            )
          },
          drinkDays: drinkDays.map { drinkDay in
            ComprehensiveExport.DrinkDayExport(
              date: drinkDay.date,
              didNotDrink: drinkDay.didNotDrink
            )
          },
          saunaDays: saunaDays.map { saunaDay in
            ComprehensiveExport.SaunaDayExport(
              date: saunaDay.date,
              didSauna: saunaDay.didSauna
            )
          },
          exercises: exercises.map { exercise in
            ComprehensiveExport.ExerciseExport(
              name: exercise.name,
              category: exercise.category,
              dateCreated: exercise.dateCreated
            )
          },
          exerciseEntries: exerciseEntries.map { entry in
            ComprehensiveExport.ExerciseEntryExport(
              date: entry.date,
              exerciseName: entry.exercise?.name ?? "Unknown",
              sets: entry.sets?.map { set in
                ComprehensiveExport.ExerciseSetExport(
                  weight: set.weight,
                  reps: set.reps
                )
              } ?? [],
              notes: entry.notes
            )
          }
        )

        // Create JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let jsonData = try encoder.encode(exportData)

        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("Jimmy_Export_\(dateForFilename()).json")

        try jsonData.write(to: tempURL)

        // Show share sheet
        await MainActor.run {
          shareURL = tempURL
          showingShareSheet = true
        }

      } catch {
        print("Export failed: \(error)")
      }
    }
  }

  private func dateForFilename() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm"
    return formatter.string(from: Date())
  }

}

struct ShareSheet: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Comprehensive Export Structure
struct ComprehensiveExport: Codable {
  let exportDate: Date
  let appVersion: String
  let settings: SettingsExport
  let workouts: [WorkoutExport]
  let drinkDays: [DrinkDayExport]
  let saunaDays: [SaunaDayExport]
  let exercises: [ExerciseExport]
  let exerciseEntries: [ExerciseEntryExport]

  struct SettingsExport: Codable {
    let showHomeTab: Bool
    let showDrinksTab: Bool
    let showSaunaTab: Bool
    let showGymTab: Bool
    let showExercisesTab: Bool
  }

  struct WorkoutExport: Codable {
    let date: Date
    let didWorkout: Bool
  }

  struct DrinkDayExport: Codable {
    let date: Date
    let didNotDrink: Bool
  }

  struct SaunaDayExport: Codable {
    let date: Date
    let didSauna: Bool
  }

  struct ExerciseExport: Codable {
    let name: String
    let category: String?
    let dateCreated: Date
  }

  struct ExerciseEntryExport: Codable {
    let date: Date
    let exerciseName: String
    let sets: [ExerciseSetExport]
    let notes: String?
  }

  struct ExerciseSetExport: Codable {
    let weight: Double
    let reps: Int
  }
}

#Preview {
  ContentView()
    .modelContainer(for: Workout.self, inMemory: true)
}
