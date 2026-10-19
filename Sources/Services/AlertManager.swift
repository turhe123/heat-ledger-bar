import Foundation
import UserNotifications

/// Sends at most one "running hot" notification per hot period, rearming after a return to nominal.
final class AlertManager {
    private var hotSince: Date?
    private var armed = true

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Evaluates the current state against the user's thresholds and posts a notification when due.
    func evaluate(level: ThermalLevel, now: Date, heavyApp: String?) {
        let defaults = UserDefaults.standard
        if level == .nominal { armed = true }
        let threshold = ThermalLevel(rawValue: defaults.object(forKey: SettingsKeys.alertLevel) as? Int ?? 2) ?? .serious
        guard defaults.object(forKey: SettingsKeys.alertsEnabled) as? Bool ?? true, level >= threshold else {
            hotSince = nil
            return
        }
        if hotSince == nil { hotSince = now }
        let minutes = defaults.object(forKey: SettingsKeys.alertMinutes) as? Int ?? 10
        guard armed, let since = hotSince, now.timeIntervalSince(since) >= Double(minutes * 60) else { return }
        armed = false
        post(level: level, minutes: minutes, heavyApp: heavyApp)
    }

    private func post(level: ThermalLevel, minutes: Int, heavyApp: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Your Mac has been \(level.name.lowercased()) for \(minutes)+ minutes"
        if let app = heavyApp {
            content.body = "\(app) is using the most CPU. Consider closing it to let your Mac cool down."
        } else {
            content.body = "Consider closing heavy apps to let your Mac cool down."
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

/// UserDefaults keys shared by settings UI and services.
enum SettingsKeys {
    static let alertMinutes = "alertMinutes"
    static let alertLevel = "alertLevel"
    static let alertsEnabled = "alertsEnabled"
    static let retentionDays = "retentionDays"
}
