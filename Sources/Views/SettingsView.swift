import ServiceManagement
import SwiftUI

/// Settings: alert threshold, retention, launch at login, and support link.
struct SettingsView: View {
    @EnvironmentObject private var ledger: ThermalLedger
    @AppStorage(SettingsKeys.alertsEnabled) private var alertsEnabled = true
    @AppStorage(SettingsKeys.alertMinutes) private var alertMinutes = 10
    @AppStorage(SettingsKeys.alertLevel) private var alertLevel = ThermalLevel.serious.rawValue
    @AppStorage(SettingsKeys.retentionDays) private var retentionDays = 30
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Notify when the Mac stays hot", isOn: $alertsEnabled)
                Picker("Alert after", selection: $alertMinutes) {
                    ForEach([5, 10, 20], id: \.self) { Text("\($0) minutes").tag($0) }
                }
                Picker("Alert level", selection: $alertLevel) {
                    Text("Serious or worse").tag(ThermalLevel.serious.rawValue)
                    Text("Critical only").tag(ThermalLevel.critical.rawValue)
                }
            }
            Section("History") {
                Picker("Keep history for", selection: $retentionDays) {
                    ForEach([7, 14, 30], id: \.self) { Text("\($0) days").tag($0) }
                }
                .onChange(of: retentionDays) { ledger.applyRetention() }
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Button("Support / Donate ❤️") { Support.openDonation() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(.vertical, 8)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't update login item: \(error.localizedDescription). You can manage it in System Settings › General › Login Items."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
