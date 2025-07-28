//
//  HealthKitManager.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import Foundation
import HealthKit

@Observable
class HealthKitManager {
  private let healthStore = HKHealthStore()

  var isAuthorized = false
  var weightData: [HealthDataPoint] = []
  var stepsData: [HealthDataPoint] = []
  var weeklyAverageWeight: Double = 0
  var lastWeekAverageWeight: Double = 0
  var weeklyAverageSteps: Double = 0

  struct HealthDataPoint {
    let date: Date
    let value: Double
  }

  init() {
    checkAuthorizationStatus()
  }

  func requestPermissions() async {
    guard HKHealthStore.isHealthDataAvailable() else {
      print("HealthKit is not available on this device")
      return
    }

    let typesToRead: Set<HKObjectType> = [
      HKObjectType.quantityType(forIdentifier: .bodyMass)!,
      HKObjectType.quantityType(forIdentifier: .stepCount)!,
    ]

    do {
      try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
      await MainActor.run {
        self.isAuthorized = true
      }
      await fetchHealthData()
    } catch {
      print("HealthKit authorization failed: \(error)")
    }
  }

  private func checkAuthorizationStatus() {
    guard HKHealthStore.isHealthDataAvailable() else { return }

    let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!

    let weightStatus = healthStore.authorizationStatus(for: weightType)
    let stepsStatus = healthStore.authorizationStatus(for: stepsType)

    isAuthorized = weightStatus == .sharingAuthorized && stepsStatus == .sharingAuthorized

    if isAuthorized {
      Task {
        await fetchHealthData()
      }
    }
  }

  func fetchHealthData() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await self.fetchWeightData()
      }
      group.addTask {
        await self.fetchStepsData()
      }
    }

    await MainActor.run {
      calculateWeeklyAverages()
    }
  }

  private func fetchWeightData() async {
    guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

    let calendar = Calendar.current
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate

    let predicate = HKQuery.predicateForSamples(
      withStart: startDate, end: endDate, options: .strictStartDate)
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: weightType,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sortDescriptor]
      ) { [weak self] _, samples, error in

        guard let samples = samples as? [HKQuantitySample], error == nil else {
          continuation.resume()
          return
        }

        let weightUnit = HKUnit.gramUnit(with: .kilo)
        let calendar = Calendar.current

        // Group samples by day and find minimum weight per day
        var dailyWeights: [Date: Double] = [:]

        for sample in samples {
          let dayStart = calendar.startOfDay(for: sample.startDate)
          let weight = sample.quantity.doubleValue(for: weightUnit)

          if let existingWeight = dailyWeights[dayStart] {
            dailyWeights[dayStart] = min(existingWeight, weight)
          } else {
            dailyWeights[dayStart] = weight
          }
        }

        // Convert to HealthDataPoint array, sorted by date
        let dataPoints = dailyWeights.map { (date, minWeight) in
          HealthDataPoint(date: date, value: minWeight)
        }.sorted { $0.date < $1.date }

        DispatchQueue.main.async {
          self?.weightData = dataPoints
        }

        continuation.resume()
      }

      healthStore.execute(query)
    }
  }

  private func fetchStepsData() async {
    guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

    let calendar = Calendar.current
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -14, to: endDate) ?? endDate

    // Create daily intervals for step count aggregation
    var dailySteps: [HealthDataPoint] = []

    for i in 0..<14 {
      guard
        let dayStart = calendar.date(
          byAdding: .day, value: -13 + i, to: calendar.startOfDay(for: endDate)),
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
      else { continue }

      let predicate = HKQuery.predicateForSamples(
        withStart: dayStart, end: dayEnd, options: .strictStartDate)

      let steps = await fetchDailySteps(for: stepsType, predicate: predicate, date: dayStart)
      dailySteps.append(HealthDataPoint(date: dayStart, value: steps))
    }

    await MainActor.run {
      self.stepsData = dailySteps
    }
  }

  private func fetchDailySteps(for stepsType: HKQuantityType, predicate: NSPredicate, date: Date)
    async -> Double
  {
    return await withCheckedContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: stepsType,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, statistics, error in

        guard let statistics = statistics, error == nil else {
          continuation.resume(returning: 0)
          return
        }

        let stepsUnit = HKUnit.count()
        let steps = statistics.sumQuantity()?.doubleValue(for: stepsUnit) ?? 0
        continuation.resume(returning: steps)
      }

      healthStore.execute(query)
    }
  }

  private func calculateWeeklyAverages() {
    // Calculate average weight for last 7 days (this week)
    let last7DaysWeight = weightData.suffix(7)
    if !last7DaysWeight.isEmpty {
      weeklyAverageWeight =
        last7DaysWeight.map { $0.value }.reduce(0, +) / Double(last7DaysWeight.count)
    }
    
    // Calculate average weight for previous 7 days (last week)
    if weightData.count >= 14 {
      let lastWeekWeight = Array(weightData.dropLast(7).suffix(7))
      if !lastWeekWeight.isEmpty {
        lastWeekAverageWeight =
          lastWeekWeight.map { $0.value }.reduce(0, +) / Double(lastWeekWeight.count)
      }
    } else if weightData.count > 7 {
      // If we have some data for last week but not a full 7 days
      let lastWeekWeight = Array(weightData.dropLast(7))
      if !lastWeekWeight.isEmpty {
        lastWeekAverageWeight =
          lastWeekWeight.map { $0.value }.reduce(0, +) / Double(lastWeekWeight.count)
      }
    }

    // Calculate average steps for last 7 days
    let last7DaysSteps = stepsData.suffix(7)
    if !last7DaysSteps.isEmpty {
      weeklyAverageSteps =
        last7DaysSteps.map { $0.value }.reduce(0, +) / Double(last7DaysSteps.count)
    }
  }
}
