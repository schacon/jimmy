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
  case fasting = "fasting"
  case gym = "gym"
  case exercises = "exercises"
  case measurements = "measurements"
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

      if appSettings.showFastingTab {
        FastingCalendarView()
          .tabItem {
            Image(systemName: "clock.arrow.circlepath")
            Text("Fasting")
          }
          .tag(AppTab.fasting)
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

      if appSettings.showMeasurementsTab {
        MeasurementsView()
          .tabItem {
            Image(systemName: "ruler")
            Text("Measurements")
          }
          .tag(AppTab.measurements)
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
        } else if appSettings.showFastingTab {
          selectedTab = .fasting
        } else if appSettings.showGymTab {
          selectedTab = .gym
        } else if appSettings.showExercisesTab {
          selectedTab = .exercises
        } else if appSettings.showMeasurementsTab {
          selectedTab = .measurements
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
  @Query private var fastingDays: [FastingDay]
  @Query private var fastingSessions: [FastingSession]
  @Query private var exerciseEntries: [ExerciseEntry]
  @Binding var selectedTab: AppTab
  @State private var healthKitManager = HealthKitManager()
  @State private var timer: Timer?
  @State private var fastingTimerText: String = ""
  @State private var showingFastingLog = false

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

  private var currentMonthRange: ClosedRange<Date> {
    let today = Date()
    let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
    return startOfMonth...today
  }

  // Set in Settings; nil or a past date hides the countdown
  private var judgementDayToShow: Date? {
    guard let judgementDay = appSettings.judgementDay else { return nil }
    let today = calendar.startOfDay(for: Date())
    guard calendar.startOfDay(for: judgementDay) >= today else { return nil }
    return judgementDay
  }

  private func daysUntil(_ judgementDay: Date) -> Int {
    let today = calendar.startOfDay(for: Date())
    let judgement = calendar.startOfDay(for: judgementDay)
    return calendar.dateComponents([.day], from: today, to: judgement).day ?? 0
  }

  private var activeFastingSession: FastingSession? {
    return fastingSessions.first(where: { $0.isActive })
  }

  private var isCurrentlyFasting: Bool {
    return activeFastingSession != nil
  }

  private var lastCompletedFast: FastingSession? {
    return fastingSessions
      .filter { !$0.isActive && $0.endTime != nil }
      .sorted { $0.startTime > $1.startTime }
      .first
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          VStack(spacing: 16) {

            // Judgement Day Countdown (if configured and not yet past)
            if let judgementDay = judgementDayToShow {
              HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                  .font(.title2)
                  .foregroundColor(.purple)

                VStack(alignment: .leading, spacing: 2) {
                  Text("Judgement Day")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                  Text(judgementDay.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                  Text("\(daysUntil(judgementDay))")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.purple)
                  
                  Text("days left")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .padding(12)
              .background(Color.purple.opacity(0.1))
              .cornerRadius(12)
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(Color.purple.opacity(0.3), lineWidth: 1)
              )
              .padding(.horizontal)
            }

            // Fasting Timer Card
            if appSettings.showFastingTab {
              FastingTimerCard(
                isCurrentlyFasting: isCurrentlyFasting,
                activeFastingSession: activeFastingSession,
                lastCompletedFast: lastCompletedFast,
                fastingTimerText: fastingTimerText,
                onStartFasting: startFasting,
                onEndFasting: endFasting,
                onNavigateToLog: {
                  showingFastingLog = true
                }
              )
              .padding(.horizontal)
            }

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

              if appSettings.showFastingTab {
                OverviewCard(
                  title: "Fasting",
                  subtitle: "Fasting days",
                  icon: "clock.arrow.circlepath",
                  color: .indigo,
                  percentage: fastingPercentage,
                  count: fastingDaysCount,
                  total: totalDaysInRange,
                  action: {
                    selectedTab = .fasting
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
        startFastingTimer()
      }
      .onDisappear {
        timer?.invalidate()
      }
      .refreshable {
        if healthKitManager.isAuthorized {
          await healthKitManager.fetchHealthData()
        }
      }
      .sheet(isPresented: $showingFastingLog) {
        FastingLogView()
      }
    }
  }

  // MARK: - Computed Properties for Stats

  private var totalDaysInRange: Int {
    (calendar.dateComponents(
      [.day], from: currentMonthRange.lowerBound, to: currentMonthRange.upperBound
    ).day ?? 0) + 1
  }

  private var drinkFreeDaysCount: Int {
    drinkDays.filter { day in
      currentMonthRange.contains(day.date) && day.didNotDrink
    }.count
  }

  private var drinkFreePercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(drinkFreeDaysCount) / Double(totalDaysInRange) * 100
  }

  private var saunaDaysCount: Int {
    saunaDays.filter { day in
      currentMonthRange.contains(day.date) && day.didSauna
    }.count
  }

  private var saunaPercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(saunaDaysCount) / Double(totalDaysInRange) * 100
  }

  private var fastingDaysCount: Int {
    fastingDays.filter { day in
      currentMonthRange.contains(day.date) && day.didFast
    }.count
  }

  private var fastingPercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(fastingDaysCount) / Double(totalDaysInRange) * 100
  }

  private var workoutDaysCount: Int {
    workouts.filter { workout in
      currentMonthRange.contains(workout.date) && workout.didWorkout
    }.count
  }

  private var workoutPercentage: Double {
    guard totalDaysInRange > 0 else { return 0 }
    return Double(workoutDaysCount) / Double(totalDaysInRange) * 100
  }

  // MARK: - Fasting Timer Functions
  
  private func startFastingTimer() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      updateFastingTimerText()
    }
    updateFastingTimerText()
  }
  
  private func updateFastingTimerText() {
    guard let session = activeFastingSession else {
      fastingTimerText = ""
      return
    }
    
    let duration = Date().timeIntervalSince(session.startTime)
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    let seconds = Int(duration) % 60
    
    fastingTimerText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
  }
  
  private func startFasting() {
    let session = FastingSession()
    modelContext.insert(session)
    try? modelContext.save()
  }
  
  private func endFasting() {
    guard let session = activeFastingSession else { return }
    session.endSession()
    
    // Auto-complete fasting day if session was 16+ hours
    let fastingDurationHours = session.duration / 3600
    if fastingDurationHours >= 16 {
      let calendar = Calendar.current
      let endTime = session.endTime ?? Date()
      let startOfDay = calendar.startOfDay(for: endTime)
      
      // Check if a fasting day entry already exists for this date
      if let existingFastingDay = fastingDays.first(where: {
        calendar.isDate($0.date, inSameDayAs: startOfDay)
      }) {
        // Update existing entry to mark as completed
        existingFastingDay.didFast = true
      } else {
        // Create new fasting day entry
        let newFastingDay = FastingDay(date: startOfDay, didFast: true)
        modelContext.insert(newFastingDay)
      }
    }
    
    try? modelContext.save()
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

struct FastingTimerCard: View {
  let isCurrentlyFasting: Bool
  let activeFastingSession: FastingSession?
  let lastCompletedFast: FastingSession?
  let fastingTimerText: String
  let onStartFasting: () -> Void
  let onEndFasting: () -> Void
  let onNavigateToLog: () -> Void

  var body: some View {
    Button(action: onNavigateToLog) {
      HStack(spacing: 12) {
        Image(systemName: "timer")
          .font(.title2)
          .foregroundColor(.mint)
        
        VStack(alignment: .leading, spacing: 2) {
          Text("Fasting Timer")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.primary)
          
          if isCurrentlyFasting {
            if let session = activeFastingSession {
              Text("Started at \(session.startTime, style: .time)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          } else {
            if let lastFast = lastCompletedFast {
              Text("Last fast: \(lastFast.durationString)")
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Text("Ready to start your fast")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          if isCurrentlyFasting {
            Text(fastingTimerText)
              .font(.system(size: 20, weight: .heavy, design: .monospaced))
              .foregroundColor(.mint)
            
            Button(action: onEndFasting) {
              Text("End")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.red)
                .cornerRadius(6)
            }
          } else {
            Button(action: onStartFasting) {
              Text("Start Fasting")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.mint)
                .cornerRadius(8)
            }
          }
        }
      }
      .padding(12)
      .background(Color.mint.opacity(0.1))
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.mint.opacity(0.3), lineWidth: 1)
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
    guard let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start else {
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
    return (calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0) + 1
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
    guard let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start else {
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
    return (calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0) + 1
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
    guard let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start else {
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
    return (calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0) + 1
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
  @Environment(CloudSyncMonitor.self) private var syncMonitor
  @Query private var settings: [AppSettings]
  @Query private var workouts: [Workout]
  @Query private var drinkDays: [DrinkDay]
  @Query private var saunaDays: [SaunaDay]
  @Query private var fastingDays: [FastingDay]
  @Query private var exercises: [Exercise]
  @Query private var exerciseEntries: [ExerciseEntry]
  @State private var shareItem: ShareItem?

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
        Section(header: Text("Judgement Day")) {
          Toggle(
            isOn: Binding(
              get: { appSettings.judgementDay != nil },
              set: { enabled in
                appSettings.judgementDay =
                  enabled
                  ? Calendar.current.date(
                    byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: Date()))
                  : nil
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.purple)
                .frame(width: 20)
              Text("Countdown")
            }
          }

          if let judgementDay = appSettings.judgementDay {
            DatePicker(
              "Date",
              selection: Binding(
                get: { judgementDay },
                set: { newValue in
                  appSettings.judgementDay = Calendar.current.startOfDay(for: newValue)
                  try? modelContext.save()
                }
              ),
              in: Calendar.current.startOfDay(for: Date())...,
              displayedComponents: .date
            )
          }
        }

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
              get: { appSettings.showFastingTab },
              set: { newValue in
                appSettings.showFastingTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.indigo)
                .frame(width: 20)
              Text("Fasting")
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

          Toggle(
            isOn: Binding(
              get: { appSettings.showMeasurementsTab },
              set: { newValue in
                appSettings.showMeasurementsTab = newValue
                try? modelContext.save()
              }
            )
          ) {
            HStack {
              Image(systemName: "ruler")
                .foregroundColor(.teal)
                .frame(width: 20)
              Text("Measurements")
            }
          }
        }

        Section(header: Text("iCloud Sync")) {
          HStack {
            Image(systemName: syncStatusIcon)
              .foregroundColor(syncStatusColor)
              .frame(width: 20)
            Text("Status")
            Spacer()
            Text(syncStatusText)
              .foregroundColor(.secondary)
          }

          HStack {
            Image(systemName: "clock.arrow.2.circlepath")
              .foregroundColor(.secondary)
              .frame(width: 20)
            Text("Last Synced")
            Spacer()
            if let lastSync = syncMonitor.lastSyncDate {
              Text(lastSync.formatted(.relative(presentation: .named)))
                .foregroundColor(.secondary)
            } else {
              Text("Never")
                .foregroundColor(.secondary)
            }
          }

          if case .failed(let message) = syncMonitor.status {
            Text(message)
              .font(.caption)
              .foregroundColor(.red)
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
            Text(syncMonitor.isCloudSyncEnabled ? "iCloud + Local" : "Local Only")
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
      .task {
        await syncMonitor.refreshAccountStatus()
      }
      .sheet(item: $shareItem) { item in
        ShareSheet(activityItems: [item.url])
      }
    }
  }

  private var syncStatusText: String {
    switch syncMonitor.status {
    case .localOnly: return "Off (Local Only)"
    case .accountUnavailable: return "iCloud Unavailable"
    case .syncing: return "Syncing…"
    case .waiting: return "Waiting to Sync"
    case .synced: return "Synced"
    case .failed: return "Sync Error"
    }
  }

  private var syncStatusIcon: String {
    switch syncMonitor.status {
    case .localOnly: return "icloud.slash"
    case .accountUnavailable: return "xmark.icloud"
    case .syncing: return "arrow.triangle.2.circlepath.icloud"
    case .waiting: return "icloud"
    case .synced: return "checkmark.icloud"
    case .failed: return "exclamationmark.icloud"
    }
  }

  private var syncStatusColor: Color {
    switch syncMonitor.status {
    case .localOnly: return .gray
    case .accountUnavailable: return .orange
    case .syncing: return .blue
    case .waiting: return .secondary
    case .synced: return .green
    case .failed: return .red
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
            showFastingTab: appSettings.showFastingTab,
            showGymTab: appSettings.showGymTab,
            showExercisesTab: appSettings.showExercisesTab,
            showMeasurementsTab: appSettings.showMeasurementsTab
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
          fastingDays: fastingDays.map { fastingDay in
            ComprehensiveExport.FastingDayExport(
              date: fastingDay.date,
              didFast: fastingDay.didFast
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
          shareItem = ShareItem(url: tempURL)
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

struct ShareItem: Identifiable {
  let id = UUID()
  let url: URL
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
  let fastingDays: [FastingDayExport]
  let exercises: [ExerciseExport]
  let exerciseEntries: [ExerciseEntryExport]

  struct SettingsExport: Codable {
    let showHomeTab: Bool
    let showDrinksTab: Bool
    let showSaunaTab: Bool
    let showFastingTab: Bool
    let showGymTab: Bool
    let showExercisesTab: Bool
    let showMeasurementsTab: Bool
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

  struct FastingDayExport: Codable {
    let date: Date
    let didFast: Bool
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

struct FastingCalendarView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var fastingDays: [FastingDay]
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
        FastingStatsBox(
          title: "Last 6 Months",
          fastingDays: fastingDays,
          dateRange: last6MonthsRange,
          isCurrentMonth: false
        )

        FastingStatsBox(
          title: "This Month",
          fastingDays: fastingDays,
          dateRange: currentMonthRange,
          isCurrentMonth: true
        )
      }
      .padding(.horizontal)

      // Calendar Grid
      FastingCalendarGrid(
        currentDate: currentDate,
        fastingDays: fastingDays,
        onDateTap: { date in
          toggleFastingDay(for: date)
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
      exportFastingDaysToJSON()
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

  private func toggleFastingDay(for date: Date) {
    let startOfDay = calendar.startOfDay(for: date)

    // Don't allow future dates
    if startOfDay > calendar.startOfDay(for: Date()) {
      return
    }

    if let existingFastingDay = fastingDays.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      // If fasting day exists, delete it (revert to no data)
      modelContext.delete(existingFastingDay)
    } else {
      // Create new fasting day entry
      let newFastingDay = FastingDay(date: startOfDay, didFast: true)
      modelContext.insert(newFastingDay)
    }

    try? modelContext.save()

    // Export to JSON after data changes
    exportFastingDaysToJSON()
  }

  private func exportFastingDaysToJSON() {
    Task {
      await saveFastingDaysToiCloudDrive()
    }
  }

  private func saveFastingDaysToiCloudDrive() async {
    guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      print("iCloud Drive not available - enable it in Xcode Capabilities")
      return
    }

    // Create Jimmy folder in iCloud Drive
    let jimmyFolderURL = iCloudURL.appendingPathComponent("Documents/Jimmy")
    let fastingDaysFileURL = jimmyFolderURL.appendingPathComponent("fastingdays.json")

    do {
      // Create directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: jimmyFolderURL, withIntermediateDirectories: true, attributes: nil)

      // Convert fasting days to JSON format
      let fastingDates = fastingDays.filter { $0.didFast }.map { fastingDay in
        FastingDayExport(date: fastingDay.date, didFast: fastingDay.didFast)
      }

      let exportData = FastingDayExportContainer(
        exportDate: Date(),
        totalFastingDays: fastingDates.count,
        fastingDays: fastingDates
      )

      // Encode to JSON
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = .prettyPrinted

      let jsonData = try encoder.encode(exportData)

      // Write to iCloud Drive
      try jsonData.write(to: fastingDaysFileURL)

      print("✅ Fasting days exported to iCloud Drive: Jimmy/fastingdays.json")

    } catch {
      print("❌ Failed to export fasting days to iCloud Drive: \(error)")
    }
  }

  private var last6MonthsRange: ClosedRange<Date> {
    let endDate = Date()
    let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate

    // Find the first date we have any fasting day data
    let firstFastingDayDate = fastingDays.map { $0.date }.min()

    // Use the later of: first fasting day date or 6 months ago
    let startDate = [firstFastingDayDate, sixMonthsAgo].compactMap { $0 }.max() ?? sixMonthsAgo

    return startDate...endDate
  }

  private var currentMonthRange: ClosedRange<Date> {
    let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
    let endOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.end ?? currentDate
    return startOfMonth...endOfMonth
  }
}

struct FastingCalendarGrid: View {
  let currentDate: Date
  let fastingDays: [FastingDay]
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
              FastingDayView(
                date: date,
                isCurrentMonth: calendar.isDate(date, equalTo: currentDate, toGranularity: .month),
                fastingStatus: fastingStatus(for: date),
                onTap: { onDateTap(date) }
              )
            }

            // Weekly checkmark for 4+ fasting days
            if hasFourFastingDaysInWeek(weekDays) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.indigo)
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
    guard let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start else {
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

  private func hasFourFastingDaysInWeek(_ weekDays: [Date]) -> Bool {
    let fastingCount = weekDays.reduce(0) { count, date in
      let startOfDay = calendar.startOfDay(for: date)
      if let fastingDay = fastingDays.first(where: {
        calendar.isDate($0.date, inSameDayAs: startOfDay)
      }), fastingDay.didFast {
        return count + 1
      }
      return count
    }
    return fastingCount >= 4
  }

  private func fastingStatus(for date: Date) -> FastingStatus {
    let startOfDay = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: Date())

    if startOfDay > today {
      return .future
    }

    if let fastingDay = fastingDays.first(where: {
      calendar.isDate($0.date, inSameDayAs: startOfDay)
    }) {
      return fastingDay.didFast ? .didFast : .didNotFast
    }

    return .noData
  }
}

struct FastingDayView: View {
  let date: Date
  let isCurrentMonth: Bool
  let fastingStatus: FastingStatus
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
    .disabled(fastingStatus == .future)
  }

  private var textColor: Color {
    if !isCurrentMonth {
      return .secondary
    }

    if fastingStatus == .future {
      return .secondary
    }

    return .primary
  }

  private var backgroundColor: Color {
    if fastingStatus == .future {
      return Color(.systemGray5)
    }

    switch fastingStatus {
    case .didFast:
      return .indigo.opacity(0.2)
    case .didNotFast:
      return .gray.opacity(0.2)
    case .noData:
      return .clear
    case .future:
      return Color(.systemGray5)
    }
  }

  private var indicatorColor: Color {
    switch fastingStatus {
    case .didFast:
      return .indigo
    case .didNotFast:
      return .gray
    case .noData:
      return .clear
    case .future:
      return .clear
    }
  }

  private var indicatorOpacity: Double {
    switch fastingStatus {
    case .didFast, .didNotFast:
      return 1.0
    case .noData, .future:
      return 0.0
    }
  }
}

struct FastingStatsBox: View {
  let title: String
  let fastingDays: [FastingDay]
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
          Image(systemName: "clock.arrow.circlepath")
            .foregroundColor(.indigo)
            .font(.caption)
          Text(
            "\(weeksWithFourPlusFastingDays)/\(isCurrentMonth ? elapsedWeeksInCurrentMonth : totalWeeksInRange) weeks"
          )
          .font(.caption2)
          .fontWeight(.medium)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text("\(Int(fastingPercentage))% days")
            .font(.title3)
            .fontWeight(.bold)

          Text("(\(fastingDaysCount)/\(totalDaysForCalculation))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        ProgressView(value: fastingPercentage / 100)
          .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
          .scaleEffect(y: 0.8)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private var fastingPercentage: Double {
    let relevantFastingDays = fastingDays.filter { fastingDay in
      dateRange.contains(fastingDay.date) && fastingDay.didFast
    }

    let totalDays = isCurrentMonth ? daysSinceStartOfMonth : daysInRange
    guard totalDays > 0 else { return 0 }

    return Double(relevantFastingDays.count) / Double(totalDays) * 100
  }

  private var fastingDaysCount: Int {
    return fastingDays.filter { fastingDay in
      dateRange.contains(fastingDay.date) && fastingDay.didFast
    }.count
  }

  private var totalDaysForCalculation: Int {
    return isCurrentMonth ? daysSinceStartOfMonth : daysInRange
  }

  private var weeksWithFourPlusFastingDays: Int {
    var weeklyFastingDays: [Int: Int] = [:]

    for fastingDay in fastingDays {
      guard dateRange.contains(fastingDay.date) && fastingDay.didFast else { continue }

      let weekOfYear = calendar.component(.weekOfYear, from: fastingDay.date)
      let year = calendar.component(.year, from: fastingDay.date)
      let weekKey = year * 100 + weekOfYear

      weeklyFastingDays[weekKey, default: 0] += 1
    }

    return weeklyFastingDays.values.filter { $0 >= 4 }.count
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
    return (calendar.dateComponents([.day], from: startOfMonth, to: endDate).day ?? 0) + 1
  }

  private var progressColor: Color {
    if fastingPercentage >= 60 {
      return .indigo
    } else if fastingPercentage >= 40 {
      return .blue
    } else if fastingPercentage >= 20 {
      return .yellow
    } else {
      return .red
    }
  }
}

enum FastingStatus {
  case didFast
  case didNotFast
  case noData
  case future
}

// MARK: - JSON Export Structures for Fasting
struct FastingDayExport: Codable {
  let date: Date
  let didFast: Bool
}

struct FastingDayExportContainer: Codable {
  let exportDate: Date
  let totalFastingDays: Int
  let fastingDays: [FastingDayExport]
}

struct FastingLogView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @Query(sort: \FastingSession.startTime, order: .reverse) private var fastingSessions: [FastingSession]
  @State private var editingSession: FastingSession?
  @State private var showingEditSheet = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(fastingSessions) { session in
          FastingSessionRow(
            session: session,
            onEdit: {
              editingSession = session
              showingEditSheet = true
            }
          )
        }
        .onDelete(perform: deleteSessions)
      }
      .navigationTitle("Fasting Log")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showingEditSheet) {
        if let session = editingSession {
          EditFastingSessionView(session: session)
        }
      }
    }
  }
  
  private func deleteSessions(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(fastingSessions[index])
      }
      try? modelContext.save()
    }
  }
}

struct FastingSessionRow: View {
  let session: FastingSession
  let onEdit: () -> Void
  
  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()
  
  var body: some View {
    Button(action: onEdit) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Started")
              .font(.caption)
              .foregroundColor(.secondary)
            Text(dateFormatter.string(from: session.startTime))
              .font(.subheadline)
              .fontWeight(.medium)
          }
          
          Spacer()
          
          if let endTime = session.endTime {
            VStack(alignment: .trailing, spacing: 2) {
              Text("Ended")
                .font(.caption)
                .foregroundColor(.secondary)
              Text(dateFormatter.string(from: endTime))
                .font(.subheadline)
                .fontWeight(.medium)
            }
          } else {
            VStack(alignment: .trailing, spacing: 2) {
              Text("Active")
                .font(.caption)
                .foregroundColor(.mint)
              Text("In Progress")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.mint)
            }
          }
        }
        
        HStack {
          Text("Duration")
            .font(.caption)
            .foregroundColor(.secondary)
          
          Spacer()
          
          Text(session.durationString)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(session.isActive ? .mint : .primary)
        }
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
  }
}

struct EditFastingSessionView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  let session: FastingSession
  @State private var startTime: Date
  @State private var endTime: Date
  @State private var isActive: Bool
  
  init(session: FastingSession) {
    self.session = session
    self._startTime = State(initialValue: session.startTime)
    self._endTime = State(initialValue: session.endTime ?? Date())
    self._isActive = State(initialValue: session.isActive)
  }
  
  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Session Details")) {
          DatePicker("Start Time", selection: $startTime)
          
          Toggle("Session Active", isOn: $isActive)
          
          if !isActive {
            DatePicker("End Time", selection: $endTime)
          }
        }
        
        Section(header: Text("Duration")) {
          HStack {
            Text("Total Duration")
            Spacer()
            Text(calculatedDurationString)
              .fontWeight(.semibold)
          }
        }
      }
      .navigationTitle("Edit Session")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            saveChanges()
            dismiss()
          }
        }
      }
    }
  }
  
  private var calculatedDurationString: String {
    let duration = isActive ? Date().timeIntervalSince(startTime) : endTime.timeIntervalSince(startTime)
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    return "\(hours)h \(minutes)m"
  }
  
  private func saveChanges() {
    session.startTime = startTime
    session.isActive = isActive
    
    if isActive {
      session.endTime = nil
    } else {
      session.endTime = endTime
    }
    
    try? modelContext.save()
  }
}

#Preview {
  ContentView()
    .modelContainer(for: Workout.self, inMemory: true)
    .environment(CloudSyncMonitor(isCloudSyncEnabled: false))
}
