import Testing
import Darwin
import Foundation
@testable import KitShell

/// 统计当前进程打开的文件描述符数量与上限。
///
/// 使用 `proc_pidinfo(PROC_PIDLISTFDS)`：它只报告本进程已打开的 fd，
/// **自身不需要新建 fd**，因此即便在 fd 接近上限时也能安全调用。
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

/// 复现 issue #119 的「后果」：fd 被耗尽后，**工具调用与网络请求会同时失败**。
///
/// 做法：不直接在测试进程里改 `RLIMIT_NOFILE`（那会污染同进程内并发运行的其他用例），
/// 而是把 limit 与消耗逻辑放进**子进程**，用 shell 的 `ulimit -n` + 占满 fd 制造耗尽，
/// 再观察该子进程里「起子进程」是否失败。
///
/// 这正是用户观察到的现象：执行很多步骤 / 运行很久之后，工具系统和网络系统一起坏掉。
/// 报错原文即 `Too many open files`。
@Suite("FD Exhaustion Impact", .serialized)
struct FDExhaustionImpactTests {

    /// 子进程隔离版：在 fd 耗尽的子进程里，起子进程会因 `Too many open files` 失败。
    ///
    /// 之所以要隔离到子进程：`RLIMIT_NOFILE` 是进程级设置，且 fd 一旦被占满，
    /// 同进程内其他并发用例也会跟着失败（这本身就是该 bug 传染性的体现）。
    @Test("子进程 fd 耗尽时工具调用会以 Too many open files 失败")
    func subprocessExhaustionBreaksToolCalls() async throws {
        let script = """
        ulimit -n 24
        i=3
        while [ $i -lt 100 ]; do
          eval "exec $i</dev/null" 2>/dev/null || break
          i=$((i+1))
        done
        echo "EXHAUSTED=$i"

        # fd 已占满：任何需要新 fd 的操作都会失败
        /bin/echo should-not-run
        ( exec 42</dev/null ) 2>&1
        """

        let result = try await ShellExecutor.execute(
            script,
            options: .init(shellExecutable: "/bin/sh", throwsOnError: false)
        )
        let output = result.stdout + result.stderr

        // 子进程确认已耗尽 fd
        #expect(output.contains("EXHAUSTED="), "子进程未报告耗尽状态：\(output)")

        // 核心证据：出现用户现场看到的同一条报错
        #expect(
            output.contains("Too many open files"),
            "预期出现 'Too many open files'，实际输出：\(output)"
        )
    }

    /// fd 充足时，同样的操作应当正常，作为因果链的对照。
    @Test("fd 充足时工具调用正常（对照组）")
    func normalConditionsWork() async throws {
        let result = try await ShellExecutor.execute(
            "/bin/echo ok",
            options: .init(shellExecutable: "/bin/sh", throwsOnError: false)
        )
        #expect(result.isSuccess)
        #expect(result.stdout.contains("ok"))
    }

    /// 记录测试进程当前的 fd 水位，便于定位「泄漏累积」类回归。
    @Test("当前进程 fd 水位可观测")
    func fileDescriptorWatermarkIsObservable() {
        let (soft, _) = FileDescriptorProbe.limit()
        let open = FileDescriptorProbe.openCount()
        print("FD-WATERMARK open=\(open) soft=\(soft)")
        #expect(open > 0, "fd 计数应可用")
        #expect(soft > 0, "应能读到 RLIMIT_NOFILE")
    }
}
