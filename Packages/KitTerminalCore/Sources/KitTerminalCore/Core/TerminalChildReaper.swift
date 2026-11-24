import Foundation

/// shell 退出收割器（#173）。
///
/// SwiftTerm 1.20.0 的 `LocalProcess.terminate()` 会先取消 childMonitor 再 kill，
/// 而 childMonitor 的退出回调是唯一执行 `waitpid` 的路径。Tab 关闭后 shell 退出
/// 时无人收割，进程表里留下 `<defunct>` 僵尸，直到 Lumi 自己退出。
/// 这里挂一个阻塞 `waitpid` 的专用线程兜底：shell 已被 `TerminalProcessTree`
/// 的 SIGKILL 升级保证死亡，线程随之结束；若 pid 已被正常路径回收，waitpid
/// 立即以 ECHILD 返回，无害。
enum TerminalChildReaper {
    static func reapAfterExit(shellPid: pid_t) {
        guard shellPid > 0 else { return }
        let thread = Thread {
            var status: Int32 = 0
            _ = waitpid(shellPid, &status, 0)
        }
        thread.name = "com.coffic.lumi.terminal-reaper"
        thread.start()
    }
}
