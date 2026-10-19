import SwiftUI

/// History window: 7/30 day comparison chart plus a per-day table.
struct HistoryView: View {
    @EnvironmentObject private var ledger: ThermalLedger
    @State private var range = 7
    @State private var confirmClear = false

    var body: some View {
        let summaries = ledger.summaries(days: range)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Range", selection: $range) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                Spacer()
                Button("Clear History…", role: .destructive) { confirmClear = true }
            }
            MultiDayChart(summaries: summaries)
                .frame(height: 200)
            Table(summaries.reversed()) {
                TableColumn("Day") { Text($0.day, format: .dateTime.weekday().month().day()) }
                TableColumn("Nominal") { Text(minutes($0, .nominal)) }
                TableColumn("Fair") { Text(minutes($0, .fair)) }
                TableColumn("Serious") { Text(minutes($0, .serious)) }
                TableColumn("Critical") { Text(minutes($0, .critical)) }
                TableColumn("Top culprit") { Text($0.topCulprit ?? "—") }
            }
        }
        .padding()
        .frame(minWidth: 620, minHeight: 480)
        .confirmationDialog("Delete all recorded thermal history?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { ledger.clearHistory() }
        }
    }

    private func minutes(_ s: DaySummary, _ level: ThermalLevel) -> String {
        let secs = s.seconds[level] ?? 0
        return secs > 0 ? formatDuration(secs) : "—"
    }
}
