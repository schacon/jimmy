//
//  Item.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import Foundation
import SwiftData

@Model
final class Workout {
    var date: Date = Date()
    var didWorkout: Bool = false
    
    init(date: Date, didWorkout: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date) // Store only the date part
        self.didWorkout = didWorkout
    }
}

@Model
final class DrinkDay {
    var date: Date = Date()
    var didNotDrink: Bool = false
    
    init(date: Date, didNotDrink: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date) // Store only the date part
        self.didNotDrink = didNotDrink
    }
}

@Model
final class SaunaDay {
    var date: Date = Date()
    var didSauna: Bool = false
    
    init(date: Date, didSauna: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date) // Store only the date part
        self.didSauna = didSauna
    }
}

@Model
final class AppSettings {
    var showHomeTab: Bool = true
    var showDrinksTab: Bool = true
    var showSaunaTab: Bool = true
    var showGymTab: Bool = true
    var showExercisesTab: Bool = true
    var showMeasurementsTab: Bool = true
    
    init() {
        self.showHomeTab = true
        self.showDrinksTab = true
        self.showSaunaTab = true
        self.showGymTab = true
        self.showExercisesTab = true
        self.showMeasurementsTab = true
    }
}

@Model
final class Exercise {
    var name: String = ""
    var category: String? = nil
    var dateCreated: Date = Date()
    
    // Inverse relationship for CloudKit
    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.exercise)
    var entries: [ExerciseEntry]? = []
    
    init(name: String, category: String? = nil) {
        self.name = name
        self.category = category
        self.dateCreated = Date()
        self.entries = []
    }
}

@Model
final class ExerciseEntry {
    var date: Date = Date()
    var exercise: Exercise?
    var notes: String? = nil
    
    // Make sets optional for CloudKit
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.entry)
    var sets: [ExerciseSet]? = []
    
    init(date: Date, exercise: Exercise) {
        self.date = Calendar.current.startOfDay(for: date)
        self.exercise = exercise
        self.sets = []
        self.notes = nil
    }
}

@Model 
final class ExerciseSet {
    var weight: Double = 0.0
    var reps: Int = 0
    var entry: ExerciseEntry?
    
    init(weight: Double, reps: Int) {
        self.weight = weight
        self.reps = reps
    }
}

@Model
final class MeasurementType {
    var name: String = ""
    var unit: String? = nil
    @Relationship(deleteRule: .cascade, inverse: \MeasurementEntry.type)
    var entries: [MeasurementEntry]? = []

    init(name: String, unit: String? = nil) {
        self.name = name
        self.unit = unit
        self.entries = []
    }
}

@Model
final class MeasurementEntry {
    var date: Date = Date()
    var value: Double = 0.0
    var type: MeasurementType?

    init(date: Date, value: Double, type: MeasurementType) {
        self.date = Calendar.current.startOfDay(for: date)
        self.value = value
        self.type = type
    }
}

