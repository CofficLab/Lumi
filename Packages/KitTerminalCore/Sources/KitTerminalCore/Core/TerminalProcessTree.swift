import Darwin
import Foundation

/// 终端会话进程树清理
///
/// 关闭终端 Tab 时，仅向 shell 自身的进程组发信号会漏掉交互式 shell 的后台作业：
/// 开启作业控制（`set -m`）后每个后台作业拥有独立 PGID，且可能忽略 HUP/TERM，
/// 于是在 Tab 关闭、甚至 1.5s 后的强制清理之后仍长期存活（#497）。
///
/// 这里递归枚举 shell 的整棵进程树，对每个 PID 直接发信号，并对树内「自身即组长」
/// 的进程额外 `killpg`，覆盖各后台作业组。绝不向组长在树外的进程组发信号，
/// 以免误杀无关进程。信号前先快照整棵树：shell 被 SIGTERM 杀死后，忽略信号的
/// 后台子进程会被重新挂到 launchd，再也无法从 shell 枚举到，必须靠快照兜底。
public enum TerminalProcessTree {
    /// 枚举 `root` 的全部后代 PID（含 `root` 自身），按发现顺序去重。
    ///
    /// 通过 `proc_listpids(PROC_ALL_PIDS)` 取全量 PID，再用
    /// `proc_pidinfo(PROC_PIDTBSDINFO)` 读每个进程的 `pbi_ppid` 建立父子映射，
    /// 从 `root` 深度优先遍历。`proc_listchildpids` 在部分 macOS 版本上返回
    /// 异常字节数，不可靠，故不使用。
    public static func descendantPIDs(of root: pid_t) -> [pid_t] {
        guard root > 1 else { return [] }

        var childrenByParent: [pid_t: [pid_t]] = [:]
        for pid in allPIDs() {
            let parent = parentPID(of: pid)
            if parent > 1 {
                childrenByParent[parent, default: []].append(pid)
            }
        }

        var result: [pid_t] = []
        var seen: Set<pid_t> = []
        var stack: [pid_t] = [root]
        // 防御异常父子关系导致的无限遍历
        var budget = 4096
        while let pid = stack.popLast(), budget > 0 {
            budget -= 1
            guard pid > 1, seen.insert(pid).inserted else { continue }
            result.append(pid)
            stack.append(contentsOf: childrenByParent[pid] ?? [])
        }
        return result
    }

    /// 终止以 `root` 为根的整棵进程树：先 SIGTERM，宽限期后对仍存活者 SIGKILL。
    ///
    /// 对树内自身即组长的进程额外 `killpg`，覆盖独立后台作业组。宽限期后的
    /// SIGKILL 基于信号前的快照，确保 shell 先死、子进程被重新挂走后仍能清理。
    public static func terminate(root: pid_t, gracePeriod: TimeInterval = 1.5) {
        let pids = descendantPIDs(of: root)
        guard !pids.isEmpty else { return }

        signal(pids, SIGTERM)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + gracePeriod) {
            let survivors = pids.filter { kill($0, 0) == 0 }
            signal(survivors, SIGKILL)
        }
    }

    // MARK: - Signaling

    private static func signal(_ pids: [pid_t], _ sig: Int32) {
        for pid in pids where pid > 1 {
            kill(pid, sig)
            // 仅当该 PID 自身即组长时才 killpg，避免误杀组长在树外的进程组。
            if getpgid(pid) == pid {
                killpg(pid, sig)
            }
        }
    }

    // MARK: - Process enumeration

    private static func allPIDs() -> [pid_t] {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return [] }
        // 预留余量：两次调用之间可能有新进程出现
        let capacity = min(Int(needed) / MemoryLayout<pid_t>.size + 64, 1 << 16)
        guard capacity > 0 else { return [] }
        var buffer = [pid_t](repeating: 0, count: capacity)
        let written = buffer.withUnsafeMutableBytes { raw in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, raw.baseAddress, Int32(raw.count))
        }
        guard written > 0 else { return [] }
        let count = min(Int(written) / MemoryLayout<pid_t>.size, capacity)
        return Array(buffer.prefix(count)).filter { $0 > 1 }
    }

    private static func parentPID(of pid: pid_t) -> pid_t {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let returned = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard returned == size else { return -1 }
        return pid_t(info.pbi_ppid)
    }
}