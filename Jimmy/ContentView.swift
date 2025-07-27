//
//  ContentView.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
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
            // Header
            Text("Gym Tracker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Month and Year
            Text(dateFormatter.string(from: currentDate))
                .font(.title2)
                .fontWeight(.semibold)
            
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
            // Toggle existing workout
            existingWorkout.didWorkout.toggle()
        } else {
            // Create new workout entry
            let newWorkout = Workout(date: startOfDay, didWorkout: true)
            modelContext.insert(newWorkout)
        }
        
        try? modelContext.save()
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
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    DayView(
                        date: date,
                        isCurrentMonth: calendar.isDate(date, equalTo: currentDate, toGranularity: .month),
                        workoutStatus: workoutStatus(for: date),
                        onTap: { onDateTap(date) }
                    )
                }
            }
        }
    }
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate),
              let firstOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start else {
            return []
        }
        
        let firstDayWeekday = calendar.component(.weekday, from: firstOfMonth)
        let numberOfEmptyDays = firstDayWeekday - 1
        
        var days: [Date] = []
        
        // Add empty days from previous month
        for i in 0..<numberOfEmptyDays {
            if let day = calendar.date(byAdding: .day, value: -(numberOfEmptyDays - i), to: firstOfMonth) {
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
        let remainingDays = 42 - days.count // 6 rows × 7 days
        let lastDayOfMonth = days.last ?? firstOfMonth
        for i in 1...remainingDays {
            if let day = calendar.date(byAdding: .day, value: i, to: lastDayOfMonth) {
                days.append(day)
            }
        }
        
        return days
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
            return .green.opacity(0.2)
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
            return .green
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

enum WorkoutStatus {
    case worked
    case didNotWork
    case noData
    case future
}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}
