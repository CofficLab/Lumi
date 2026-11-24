import Darwin
import Foundation
import Testing
@testable import KitTerminalCore

@Suite("终端子进程收割")
struct TerminalChildReaperTests {
    @Test("终止后子进程被收割，进程表不残留僵尸（回归 #173）")
    func childIsReapedAfterTermination() async throws {
        let childPid = try spawnLongRunningChild()
        defer {
            // 兜底：断言失败留下僵尸时收割一次，避免污染测试进程。
            var status: Int32 = 0
            _ = waitpid(childPid, &status, WNOHANG)
        }

        // 模拟 Tab 关闭流程：收割线程先挂起等待，随后子进程被强杀
        // （生产中由 TerminalProcessTree 的 SIGKILL 升级保证死亡）。
        TerminalChildReaper.reapAfterExit(shellPid: childPid)
        kill(childPid, SIGKILL)

        // kill(pid, 0)：存活与僵尸都返回 0，收割后返回 ESRCH；未收割的
        // 僵尸在父进程存活期间一直留在进程表里。
        var reaped = false
        for _ in 0..<60 {
            if kill(childPid, 0) == -1 {
                reaped = true
                break
            }
            usleep(50_000)
        }
        #expect(reaped, "子进程被终止后必须被 waitpid 收割，不能残留僵尸（回归 #173）")
    }
}

/// 拉起一个存活的子进程，其 pid 归测试进程所有，只能靠 waitpid 收割。
private func spawnLongRunningChild() throws -> pid_t {
    var attr: posix_spawnattr_t? = nil
    posix_spawnattr_init(&attr)
    defer { posix_spawnattr_destroy(&attr) }

    let args: [UnsafeMutablePointer<CChar>?] = [strdup("sleep"), strdup("30"), nil]
    let env: [UnsafeMutablePointer<CChar>?] = [strdup("PATH=/usr/bin:/bin"), nil]
    defer {
        args.compactMap { $0 }.forEach { free($0) }
        env.compactMap { $0 }.forEach { free($0) }
    }

    var pid: pid_t = 0
    let rc = posix_spawn(&pid, "/bin/sleep", nil, &attr, args, env)
    guard rc == 0 else {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "posix_spawn failed: \(rc)"])
    }
    return pid
}
