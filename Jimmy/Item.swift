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
    var date: Date
    var didWorkout: Bool
    
    init(date: Date, didWorkout: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date) // Store only the date part
        self.didWorkout = didWorkout
    }
}
