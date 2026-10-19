import Charts
import SwiftUI

/// A single horizontal stacked bar showing the share of a day spent in each thermal level.
struct DayBarChart: View {
    let summary: DaySummary

    var body: some View {
        Chart {
            ForEach(ThermalLevel.allCases) { level in
                BarMark(x: .value("Minutes", (summary.seconds[level] ?? 0) / 60), y: .value("Day", "Today"))
                    .foregroundStyle(by: .value("State", level.name))
            }
        }
        .chartForegroundStyleScale(domain: ThermalLevel.allCases.map(\.name), range: ThermalLevel.allCases.map(\.color))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel { if let m = value.as(Double.self) { Text(formatDuration(m * 60)) } }
            }
        }
        .chartLegend(position: .bottom, spacing: 6)
        .frame(height: 70)
    }
}

/// Vertical stacked bars comparing several days, one bar per day.
struct MultiDayChart: View {
    let summaries: [DaySummary]

    var body: some View {
        Chart {
            ForEach(summaries) { s in
                ForEach(ThermalLevel.allCases) { level in
                    BarMark(x: .value("Day", s.day, unit: .day), y: .value("Hours", (s.seconds[level] ?? 0) / 3600))
                        .foregroundStyle(by: .value("State", level.name))
                }
            }
        }
        .chartForegroundStyleScale(domain: ThermalLevel.allCases.map(\.name), range: ThermalLevel.allCases.map(\.color))
        .chartYAxisLabel("Hours")
    }
}
