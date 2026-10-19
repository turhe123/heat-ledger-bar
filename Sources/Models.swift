import Foundation
import SwiftUI

/// The four official system thermal levels, mirrored from `ProcessInfo.ThermalState`.
enum ThermalLevel: Int, Codable, CaseIterable, Comparable, Identifiable {
    case nominal = 0, fair, serious, critical

    var id: Int { rawValue }

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .critical
        }
    }

    static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var name: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        }
    }

    var summary: String {
        switch self {
        case .nominal: return "Running cool"
        case .fair: return "Slightly warm"
        case .serious: return "Hot — performance may be throttled"
        case .critical: return "Very hot — heavy throttling"
        }
    }

    var color: Color {
        switch self {
        case .nominal: return .gray
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }

    var nsColor: NSColor {
        switch self {
        case .nominal: return .systemGray
        case .fair: return .systemYellow
        case .serious: return .systemOrange
        case .critical: return .systemRed
        }
    }

    var isHot: Bool { self >= .fair }
}

/// One contiguous span of time spent in a single thermal level, plus the apps involved.
struct ThermalInterval: Codable, Identifiable, Equatable {
    static let maxCulprits = 5

    var id = UUID()
    var level: ThermalLevel
    var start: Date
    var end: Date?
    /// True when the app launched while the Mac was already in this state.
    var partial: Bool = false
    /// Apps that were frontmost during the interval, in order of appearance.
    var frontmostApps: [String] = []
    /// Heaviest apps by CPU time during the interval, heaviest first.
    var heavyApps: [String] = []

    /// Duration clipped to `[from, to]`; negative spans (clock changes) count as zero.
    func duration(from: Date = .distantPast, to: Date = .distantFuture, now: Date = Date()) -> TimeInterval {
        let s = max(start, from)
        let e = min(end ?? now, to)
        return max(0, e.timeIntervalSince(s))
    }

    mutating func addFrontmost(_ name: String) {
        guard !name.isEmpty, !frontmostApps.contains(name), frontmostApps.count < Self.maxCulprits else { return }
        frontmostApps.append(name)
    }
}

/// Seconds spent in each thermal level during one calendar day.
struct DaySummary: Identifiable {
    let day: Date
    var seconds: [ThermalLevel: TimeInterval]
    var topCulprit: String?

    var id: Date { day }
    var total: TimeInterval { seconds.values.reduce(0, +) }
    var hotSeconds: TimeInterval { seconds.filter { $0.key.isHot }.values.reduce(0, +) }
    func minutes(_ level: ThermalLevel) -> Int { Int((seconds[level] ?? 0) / 60) }
}

/// Formats a duration as e.g. "1h 12m" or "4m".
func formatDuration(_ seconds: TimeInterval) -> String {
    let m = Int(seconds / 60)
    if m < 1 { return "<1m" }
    return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
}
