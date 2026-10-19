import AppKit
import Combine
import Foundation

/// Records thermal-state intervals, tracks culprit apps while hot, persists the log as JSON, and drives alerts.
@MainActor
final class ThermalLedger: ObservableObject {
    @Published private(set) var intervals: [ThermalInterval] = []
    @Published private(set) var currentLevel: ThermalLevel = .nominal
    @Published var lastError: String?

    private let sampler = ProcessSampler()
    private let alerts = AlertManager()
    private var heavyTotals: [String: Double] = [:]
    private var sampleTimer: Timer?
    private var tickTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private let ownName = ProcessInfo.processInfo.processName

    private var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("HeatLedgerBar", isDirectory: true).appendingPathComponent("intervals.json")
    }

    init() {
        load()
        closeDanglingIntervals()
        prune()
        alerts.requestAuthorization()
        open(level: ThermalLevel(ProcessInfo.processInfo.thermalState), partial: true)
        observe()
        // Refresh views periodically so the open interval's duration grows.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
    }

    // MARK: - Observation

    private func observe() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.thermalStateChanged() }
        })
        observers.append(nc.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeCurrent() }
        })
        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.closeCurrent() }
        })
        observers.append(ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.open(level: ThermalLevel(ProcessInfo.processInfo.thermalState), partial: false) }
        })
        observers.append(ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let name = app?.localizedName
            Task { @MainActor in self?.frontmostChanged(name) }
        })
    }

    private func thermalStateChanged() {
        let level = ThermalLevel(ProcessInfo.processInfo.thermalState)
        guard level != currentLevel || openIndex == nil else { return }
        open(level: level, partial: false)
    }

    private func frontmostChanged(_ name: String?) {
        guard let name, currentLevel.isHot, let i = openIndex else { return }
        intervals[i].addFrontmost(name)
        save()
    }

    // MARK: - Intervals

    private var openIndex: Int? { intervals.lastIndex { $0.end == nil } }

    /// Closes the open interval (if any) and starts a new one at `level`.
    private func open(level: ThermalLevel, partial: Bool) {
        closeCurrent()
        let now = Date()
        var interval = ThermalInterval(level: level, start: now, partial: partial && level.isHot)
        if let front = NSWorkspace.shared.frontmostApplication?.localizedName { interval.addFrontmost(front) }
        intervals.append(interval)
        currentLevel = level
        heavyTotals.removeAll()
        sampler.reset()
        updateSampling()
        alerts.evaluate(level: level, now: now, heavyApp: nil)
        prune()
        save()
    }

    /// Ends the open interval now; negative durations from clock changes are clamped.
    private func closeCurrent() {
        guard let i = openIndex else { return }
        let now = Date()
        intervals[i].end = max(now, intervals[i].start)
        sampleTimer?.invalidate()
        sampleTimer = nil
        save()
    }

    /// Intervals left open by a crash or forced quit have an unknown end, so close them at their start.
    private func closeDanglingIntervals() {
        for i in intervals.indices where intervals[i].end == nil {
            intervals[i].end = intervals[i].start
        }
    }

    // MARK: - CPU sampling

    private func updateSampling() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        guard currentLevel.isHot else { return }
        _ = sampler.sample() // baseline
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleNow() }
        }
    }

    private func sampleNow() {
        guard let i = openIndex, currentLevel.isHot else { return }
        for (name, delta) in sampler.sample() where name != ownName {
            heavyTotals[name, default: 0] += delta
        }
        let ranked = heavyTotals.sorted { $0.value > $1.value }.prefix(ThermalInterval.maxCulprits).map(\.key)
        intervals[i].heavyApps = Array(ranked)
        alerts.evaluate(level: currentLevel, now: Date(), heavyApp: ranked.first)
        save()
    }

    // MARK: - Queries

    /// Most recent hot intervals, newest first.
    func recentHotPeriods(limit: Int = 3) -> [ThermalInterval] {
        Array(intervals.filter { $0.level.isHot && ($0.end == nil || $0.duration() > 0) }.reversed().prefix(limit))
    }

    /// Per-level time for the calendar day containing `day`.
    func summary(for day: Date) -> DaySummary {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        var seconds: [ThermalLevel: TimeInterval] = [:]
        var culprits: [String: TimeInterval] = [:]
        for interval in intervals where interval.start < end && (interval.end ?? Date()) > start {
            let d = interval.duration(from: start, to: end)
            seconds[interval.level, default: 0] += d
            if interval.level.isHot, let app = interval.heavyApps.first ?? interval.frontmostApps.first {
                culprits[app, default: 0] += d
            }
        }
        return DaySummary(day: start, seconds: seconds, topCulprit: culprits.max { $0.value < $1.value }?.key)
    }

    /// Summaries for the last `days` days, oldest first.
    func summaries(days: Int) -> [DaySummary] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: today).map(summary(for:))
        }
    }

    /// Deletes all history and starts a fresh interval for the current state.
    func clearHistory() {
        sampleTimer?.invalidate()
        intervals.removeAll()
        open(level: ThermalLevel(ProcessInfo.processInfo.thermalState), partial: true)
    }

    // MARK: - Persistence

    private func prune() {
        let stored = UserDefaults.standard.object(forKey: SettingsKeys.retentionDays) as? Int ?? 30
        let days = min(max(stored, 1), 30)
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        intervals.removeAll { ($0.end ?? Date()) < cutoff }
    }

    func applyRetention() {
        prune()
        save()
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        do {
            intervals = try JSONDecoder.ledger.decode([ThermalInterval].self, from: data)
        } catch {
            lastError = "Could not read history: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.ledger.encode(intervals).write(to: url, options: .atomic)
        } catch {
            lastError = "Could not save history: \(error.localizedDescription)"
        }
    }
}

private extension JSONEncoder {
    static let ledger: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let ledger: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
