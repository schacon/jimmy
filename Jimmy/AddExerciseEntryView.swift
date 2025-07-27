//
//  AddExerciseEntryView.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import SwiftUI
import SwiftData

struct AddExerciseEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    
    let selectedDate: Date
    
    @State private var selectedExercise: Exercise?
    @State private var newExerciseName = ""
    @State private var newExerciseCategory = ""
    @State private var showingNewExerciseForm = false
    @State private var sets: [ExerciseSetInput] = [ExerciseSetInput()]
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise") {
                    if exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No exercises available")
                                .foregroundColor(.secondary)
                            
                            Button("Create First Exercise") {
                                showingNewExerciseForm = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Picker("Select Exercise", selection: $selectedExercise) {
                            Text("Select an exercise").tag(nil as Exercise?)
                            ForEach(exercises, id: \.self) { exercise in
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    if let category = exercise.category, !category.isEmpty {
                                        Text(category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(exercise as Exercise?)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Button("Add New Exercise") {
                            showingNewExerciseForm = true
                        }
                    }
                }
                
                if selectedExercise != nil {
                    Section("Sets") {
                        ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Set \(index + 1)")
                                    .font(.headline)
                                
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Weight (lbs)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField("0", value: $sets[index].weight, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .keyboardType(.decimalPad)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text("Reps")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        TextField("0", value: $sets[index].reps, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .keyboardType(.numberPad)
                                    }
                                    
                                    if sets.count > 1 {
                                        Button(action: { removeSet(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Button("Add Set") {
                            addSet()
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Section("Notes (Optional)") {
                        TextField("Add notes about this workout...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(selectedExercise == nil || sets.allSatisfy { $0.weight <= 0 && $0.reps <= 0 })
                }
            }
            .sheet(isPresented: $showingNewExerciseForm) {
                NewExerciseView { exercise in
                    selectedExercise = exercise
                    showingNewExerciseForm = false
                }
            }
        }
    }
    
    private func addSet() {
        sets.append(ExerciseSetInput())
    }
    
    private func removeSet(at index: Int) {
        sets.remove(at: index)
    }
    
    private func saveEntry() {
        guard let exercise = selectedExercise else { return }
        
        let entry = ExerciseEntry(date: selectedDate, exercise: exercise)
        entry.notes = notes.isEmpty ? nil : notes
        
        // Initialize sets array if nil
        if entry.sets == nil {
            entry.sets = []
        }
        
        for setInput in sets {
            if setInput.weight > 0 || setInput.reps > 0 {
                let exerciseSet = ExerciseSet(weight: setInput.weight, reps: setInput.reps)
                exerciseSet.entry = entry
                entry.sets?.append(exerciseSet)
                modelContext.insert(exerciseSet)
            }
        }
        
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

struct ExerciseSetInput {
    var weight: Double = 0
    var reps: Int = 0
}

struct NewExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let onExerciseCreated: (Exercise) -> Void
    
    @State private var name = ""
    @State private var category = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)
                    TextField("Category (Optional)", text: $category)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveExercise() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        modelContext.insert(exercise)
        try? modelContext.save()
        
        onExerciseCreated(exercise)
    }
}

#Preview {
    AddExerciseEntryView(selectedDate: Date())
        .modelContainer(for: [Exercise.self, ExerciseEntry.self, ExerciseSet.self], inMemory: true)
} 