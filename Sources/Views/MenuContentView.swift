import SwiftUI

/// The menu bar popover: current state, today's bar, recent hot periods, and actions.
struct MenuContentView: View {
    @EnvironmentObject private var ledger: ThermalLedger
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let today = ledger.summary(for: Date())
        let hot = ledger.recentHotPeriods()
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "thermometer.medium")
                    .font(.title)
                    .foregroundStyle(ledger.currentLevel.color)
                VStack(alignment: .leading) {
                    Text(ledger.currentLevel.name).font(.headline)
                    Text(ledger.currentLevel.summary).font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()
            Text("Today").font(.subheadline.bold())
            DayBarChart(summary: today)

            Divider()
            if today.hotSeconds == 0 && hot.allSatisfy({ !Calendar.current.isDateInToday($0.start) }) {
                Label("Your Mac has stayed cool today", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if !hot.isEmpty {
                Text("Recent hot periods").font(.subheadline.bold())
                ForEach(hot) { HotPeriodRow(interval: $0) }
            }

            if let error = ledger.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Divider()
            HStack {
                Button("View History") {
                    openWindow(id: "history")
                    NSApp.activate(ignoringOtherApps: true)
                }
                SettingsLink { Text("Settings…") }
                    .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            Button("Support / Donate ❤️") { Support.openDonation() }
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 340)
    }
}

/// One hot interval with its frontmost app and heaviest apps.
struct HotPeriodRow: View {
    let interval: ThermalInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle().fill(interval.level.color).frame(width: 8, height: 8)
                Text(interval.level.name).bold()
                Text(interval.start, format: .dateTime.hour().minute())
                Text("· \(formatDuration(interval.duration()))\(interval.end == nil ? " (ongoing)" : "")")
                if interval.partial { Text("partial").font(.caption2).foregroundStyle(.secondary) }
            }
            .font(.caption)
            if let front = interval.frontmostApps.first {
                Text("Frontmost: \(front)").font(.caption2).foregroundStyle(.secondary)
            }
            if !interval.heavyApps.isEmpty {
                Text("Heaviest: \(interval.heavyApps.prefix(3).joined(separator: ", "))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
