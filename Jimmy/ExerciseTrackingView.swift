//
//  ExerciseTrackingView.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @Query private var exerciseEntries: [ExerciseEntry]
    @State private var selectedDate = Date()
    @State private var showingAddExercise = false
    @State private var showingAddEntry = false
    @State private var showingDatePicker = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    var filteredEntries: [ExerciseEntry] {
        let calendar = Calendar.current
        return exerciseEntries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current Date Display with Change Button
                VStack(spacing: 12) {
                    Text(dateFormatter.string(from: selectedDate))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingDatePicker.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text(showingDatePicker ? "Hide Calendar" : "Change Date")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Collapsible Date Picker
                if showingDatePicker {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Date")
                            .font(.headline)
                        
                        DatePicker(
                            "Workout Date",
                            selection: Binding(
                                get: { selectedDate },
                                set: { newDate in
                                    selectedDate = newDate
                                    // Hide picker after selection
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingDatePicker = false
                                    }
                                }
                            ),
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .frame(maxHeight: 300)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
                
                // Exercise Entries for Selected Date
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Exercises")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingAddEntry = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if filteredEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("No exercises logged for this date")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Add Exercise") {
                                showingAddEntry = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredEntries, id: \.self) { entry in
                                    ExerciseEntryCard(entry: entry)
                                }
                            }
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Exercise Tracking")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manage Exercises") {
                        showingAddExercise = true
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                ExerciseManagementView()
            }
            .sheet(isPresented: $showingAddEntry) {
                AddExerciseEntryView(selectedDate: selectedDate)
            }
        }
    }
}

struct ExerciseEntryCard: View {
    let entry: ExerciseEntry
    @Environment(\.modelContext) private var modelContext
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.exercise?.name ?? "Unknown Exercise")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        if let category = entry.exercise?.category, !category.isEmpty {
                            Text(category)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        // Stats display
                        if let sets = entry.sets, !sets.isEmpty {
                            let avgWeight = averageWeight(sets: sets)
                            let totalRepsCount = totalReps(sets: sets)
                            
                            if avgWeight > 0 || totalRepsCount > 0 {
                                HStack(spacing: 8) {
                                    if avgWeight > 0 {
                                        Text("Avg: \(Int(avgWeight)) lbs")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if avgWeight > 0 && totalRepsCount > 0 {
                                        Text("•")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if totalRepsCount > 0 {
                                        Text("Total: \(totalRepsCount) reps")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    Button("Edit") {
                        showingEdit = true
                    }
                    
                    Button("Delete", role: .destructive) {
                        deleteEntry()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            

            
            // Notes
            if let notes = entry.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(notes)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingEdit) {
            EditExerciseEntryView(entry: entry)
        }
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
        try? modelContext.save()
    }
    
    private func averageWeight(sets: [ExerciseSet]) -> Double {
        let setsWithWeight = sets.filter { $0.weight > 0 }
        let totalWeight = setsWithWeight.reduce(0) { $0 + $1.weight }
        return setsWithWeight.isEmpty ? 0 : totalWeight / Double(setsWithWeight.count)
    }
    
    private func totalReps(sets: [ExerciseSet]) -> Int {
        return sets.reduce(0) { $0 + $1.reps }
    }
}

#Preview {
    ExerciseTrackingView()
        .modelContainer(for: [Exercise.self, ExerciseEntry.self, ExerciseSet.self], inMemory: true)
} 