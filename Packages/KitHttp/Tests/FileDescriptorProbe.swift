import Darwin
import Foundation

/// 统计当前进程打开的文件描述符数量与上限。
///
/// 使用 `proc_pidinfo(PROC_PIDLISTFDS)`：它只报告本进程已打开的 fd，
/// **自身不需要新建 fd**，因此即便在 fd 接近上限时也能安全调用，
/// 适合观测「fd 是否随操作持续累积」（fd 泄漏的判据）。
enum FileDescriptorProbe {

    /// 当前进程打开的 fd 数量；调用失败返回 -1。
    static func openCount() -> Int {
        let pid = getpid()
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return -1 }

        let capacity = Int(needed) / MemoryLayout<proc_fdinfo>.stride + 16
        var buffer = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let got = proc_pidinfo(
            pid,
            PROC_PIDLISTFDS,
            0,
            &buffer,
            Int32(capacity * MemoryLayout<proc_fdinfo>.stride)
        )
        guard got > 0 else { return -1 }
        return Int(got) / MemoryLayout<proc_fdinfo>.stride
    }

    /// 当前进程的 `RLIMIT_NOFILE`（soft/hard）。
    static func limit() -> (soft: UInt64, hard: UInt64) {
        var value = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &value) == 0 else { return (0, 0) }
        return (value.rlim_cur, value.rlim_max)
    }
}
