//
//  ExerciseManagementView.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import SwiftUI
import SwiftData

struct ExerciseManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @State private var showingAddExercise = false
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises.sorted { $0.name < $1.name }
        } else {
            return exercises.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if exercises.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Exercises Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add your first exercise to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Add Exercise") {
                            showingAddExercise = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredExercises, id: \.self) { exercise in
                            ExerciseRow(exercise: exercise)
                        }
                        .onDelete(perform: deleteExercises)
                    }
                    .searchable(text: $searchText, prompt: "Search exercises")
                }
            }
            .navigationTitle("Manage Exercises")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddExercise = true
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                NewExerciseView { _ in
                    showingAddExercise = false
                }
            }
        }
    }
    
    private func deleteExercises(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredExercises[index])
            }
            try? modelContext.save()
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
            
            if let category = exercise.category, !category.isEmpty {
                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditExerciseView(exercise: exercise)
        }
    }
}

struct EditExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let exercise: Exercise
    
    @State private var name: String
    @State private var category: String
    
    init(exercise: Exercise) {
        self.exercise = exercise
        self._name = State(initialValue: exercise.name)
        self._category = State(initialValue: exercise.category ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Details") {
                    TextField("Exercise Name", text: $name)
                    TextField("Category (Optional)", text: $category)
                }
            }
            .navigationTitle("Edit Exercise")
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
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditExerciseEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let entry: ExerciseEntry
    
    @State private var sets: [ExerciseSetInput] = []
    @State private var notes: String
    
    init(entry: ExerciseEntry) {
        self.entry = entry
        self._notes = State(initialValue: entry.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    HStack {
                        Text("Exercise:")
                        Spacer()
                        Text(entry.exercise?.name ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    if let category = entry.exercise?.category, !category.isEmpty {
                        HStack {
                            Text("Category:")
                            Spacer()
                            Text(category)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
            .navigationTitle("Edit Exercise")
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
                    }
                }
            }
            .onAppear {
                loadSets()
            }
        }
    }
    
    private func loadSets() {
        if let entrySets = entry.sets {
            sets = entrySets.map { ExerciseSetInput(weight: $0.weight, reps: $0.reps) }
        }
        if sets.isEmpty {
            sets = [ExerciseSetInput()]
        }
    }
    
    private func addSet() {
        // Copy weight from previous set if available
        let previousWeight = sets.last?.weight ?? 0
        sets.append(ExerciseSetInput(weight: previousWeight, reps: 0))
    }
    
    private func removeSet(at index: Int) {
        sets.remove(at: index)
    }
    
    private func saveChanges() {
        // Remove existing sets
        if let existingSets = entry.sets {
            for set in existingSets {
                modelContext.delete(set)
            }
        }
        entry.sets = []
        
        // Add new sets
        for setInput in sets {
            if setInput.weight > 0 || setInput.reps > 0 {
                let exerciseSet = ExerciseSet(weight: setInput.weight, reps: setInput.reps)
                exerciseSet.entry = entry
                entry.sets?.append(exerciseSet)
                modelContext.insert(exerciseSet)
            }
        }
        
        // Update notes
        entry.notes = notes.isEmpty ? nil : notes
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ExerciseManagementView()
        .modelContainer(for: [Exercise.self, ExerciseEntry.self, ExerciseSet.self], inMemory: true)
} 