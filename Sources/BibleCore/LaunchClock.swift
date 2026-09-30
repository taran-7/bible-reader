import Darwin
import Foundation

/// Time since process start (NFR-3: launch < 1 s). The start comes from the kernel (`kinfo_proc.p_starttime`),
/// so the measurement includes everything: loading the binary, the app's `init`, opening the database, the first render.
public enum LaunchClock {
    public static func processStart(pid: pid_t = getpid()) -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000)
    }

    /// Milliseconds from process start to `now`.
    public static func millisecondsSinceStart(now: Date = Date()) -> Int? {
        processStart().map { Int((now.timeIntervalSince($0) * 1000).rounded()) }
    }
}
