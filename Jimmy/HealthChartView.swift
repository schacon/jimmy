//
//  HealthChartView.swift
//  Jimmy
//
//  Created by Scott Chacon on 7/27/25.
//

import SwiftUI
import Charts

struct HealthDataCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let data: [HealthKitManager.HealthDataPoint]
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            // Mini Chart
            if !data.isEmpty {
                Chart(data, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color.opacity(0.2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 60)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 60)
                    .overlay(
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
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
}

struct DetailedHealthChartView: View {
    let title: String
    let data: [HealthKitManager.HealthDataPoint]
    let color: Color
    let unit: String
    let icon: String
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if !data.isEmpty {
                // Chart
                Chart(data, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(color.opacity(0.2))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)
                
                // Stats
                HStack {
                    VStack(alignment: .leading) {
                        Text("Latest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(data.last?.value ?? 0, specifier: "%.1f") \(unit)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("7-day avg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        let avg = data.suffix(7).map { $0.value }.reduce(0, +) / Double(min(7, data.count))
                        Text("\(avg, specifier: "%.1f") \(unit)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top, 8)
                
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No data available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Enable HealthKit permissions to see your \(title.lowercased()) data")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
} 