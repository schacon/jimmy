import SwiftUI
import SwiftData

struct MeasurementsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var measurementTypes: [MeasurementType]
  @State private var showingAddType = false

  var body: some View {
    NavigationView {
      List {
        ForEach(measurementTypes) { type in
          NavigationLink(destination: MeasurementDetailView(measurementType: type)) {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(type.name)
                if let lastEntry = type.entries?.sorted(by: { $0.date > $1.date }).first {
                  Text("Last: \(lastEntry.value, specifier: "%.1f")\(type.unit.map { " \($0)" } ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              Spacer()
              if let unit = type.unit, !unit.isEmpty {
                Text(unit)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        .onDelete(perform: deleteTypes)
      }
      .navigationTitle("Measurements")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingAddType = true }) {
            Image(systemName: "plus")
          }
        }
      }
      .sheet(isPresented: $showingAddType) {
        AddMeasurementTypeView()
      }
    }
  }

  private func deleteTypes(at offsets: IndexSet) {
    for index in offsets {
      let type = measurementTypes[index]
      modelContext.delete(type)
    }
    try? modelContext.save()
  }
}

struct AddMeasurementTypeView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var name = ""
  @State private var unit = "cm"
  
  private let unitOptions = ["cm", "mm", "inches"]

  var body: some View {
    NavigationView {
      Form {
        Section {
          TextField("Name", text: $name)
          Picker("Unit", selection: $unit) {
            ForEach(unitOptions, id: \.self) { option in
              Text(option).tag(option)
            }
          }
          .pickerStyle(MenuPickerStyle())
        }
      }
      .navigationTitle("New Measurement")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }
            .disabled(name.isEmpty)
        }
      }
    }
  }

  private func save() {
    let type = MeasurementType(name: name, unit: unit)
    modelContext.insert(type)
    try? modelContext.save()
    dismiss()
  }
}

struct MeasurementDetailView: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var measurementType: MeasurementType
  @State private var value = ""
  @State private var date = Date()

  private var entries: [MeasurementEntry] {
    (measurementType.entries ?? []).sorted { $0.date > $1.date }
  }

  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
  }()

  var body: some View {
    List {
      Section(header: Text("Add Entry")) {
        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
        TextField("Value", text: $value)
          .keyboardType(.decimalPad)
        Button("Save", action: addEntry)
          .disabled(Double(value) == nil)
      }
      Section(header: Text("History")) {
        if entries.isEmpty {
          Text("No entries yet")
            .foregroundColor(.secondary)
        } else {
          ForEach(entries) { entry in
            HStack {
              Text(dateFormatter.string(from: entry.date))
              Spacer()
              Text("\(entry.value, specifier: "%.2f") \(measurementType.unit ?? "")")
            }
          }
        }
      }
    }
    .navigationTitle(measurementType.name)
  }

  private func addEntry() {
    guard let val = Double(value) else { return }
    let entry = MeasurementEntry(date: date, value: val, type: measurementType)
    modelContext.insert(entry)
    try? modelContext.save()
    value = ""
  }
}

#Preview {
  MeasurementsView()
}

