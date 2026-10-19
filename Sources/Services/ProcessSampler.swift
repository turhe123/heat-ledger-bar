import AppKit
import Darwin

/// Samples per-process CPU time via `proc_pid_rusage` and reports which apps consumed the most since the last sample.
final class ProcessSampler {
    private var lastCPU: [pid_t: UInt64] = [:]

    /// Forgets the previous baseline so the next sample starts fresh.
    func reset() { lastCPU.removeAll() }

    /// Returns CPU-time deltas grouped by app name since the previous call (empty on the first call).
    func sample() -> [String: Double] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [:] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let filled = pids.withUnsafeMutableBufferPointer { buf in
            proc_listallpids(buf.baseAddress, Int32(buf.count * MemoryLayout<pid_t>.size))
        }
        guard filled > 0 else { return [:] }

        let hadBaseline = !lastCPU.isEmpty
        var current: [pid_t: UInt64] = [:]
        var deltas: [String: Double] = [:]
        for pid in pids.prefix(Int(filled)) where pid > 0 {
            guard let cpu = cpuTime(pid) else { continue }
            current[pid] = cpu
            guard hadBaseline, let prev = lastCPU[pid], cpu > prev else { continue }
            deltas[appName(pid), default: 0] += Double(cpu - prev)
        }
        lastCPU = current
        return deltas
    }

    private func cpuTime(_ pid: pid_t) -> UInt64? {
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        guard result == 0 else { return nil }
        return info.ri_user_time &+ info.ri_system_time
    }

    private func appName(_ pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName, !name.isEmpty {
            return name
        }
        var buffer = [CChar](repeating: 0, count: 256)
        let len = proc_name(pid, &buffer, UInt32(buffer.count))
        return len > 0 ? String(cString: buffer) : "pid \(pid)"
    }
}
