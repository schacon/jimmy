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
final class Exercise {
    var name: String = ""
    var category: String? = nil
    var dateCreated: Date = Date()
    
    init(name: String, category: String? = nil) {
        self.name = name
        self.category = category
        self.dateCreated = Date()
    }
}

@Model
final class ExerciseEntry {
    var date: Date = Date()
    var exercise: Exercise?
    var sets: [ExerciseSet] = []
    var notes: String? = nil
    
    init(date: Date, exercise: Exercise) {
        self.date = Calendar.current.startOfDay(for: date)
        self.exercise = exercise
        self.sets = []
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
