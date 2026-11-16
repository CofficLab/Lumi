import Darwin
import Foundation
import Testing
@testable import KitTerminalCore

/// 进程树清理回归（#497）
///
/// 关闭终端 Tab 时，交互式 shell 的后台作业拥有独立 PGID 且可能忽略 HUP/TERM，
/// 仅 killpg(shellPid) 会让它们在 Tab 关闭后长期存活。这里用真实进程树锁定：
/// 枚举整棵树、对每个 PID 直接 SIGKILL、信号前快照（shell 先死后子进程被挂走仍能清理），
/// 以及不误杀树外进程。
@Suite("TerminalProcessTree Tests", .serialized)
struct TerminalProcessTreeTests {

    private enum TestError: Error {
        case pidFileTimeout(String)
    }

    // MARK: - Enumeration

    @Test("descendantPIDs 递归枚举真实进程树（含孙进程）")
    func descendantPIDsEnumeratesRealProcessTree() async throws {
        let childFile = tempPath()
        let grandFile = tempPath()
        defer { remove(childFile); remove(grandFile) }

        // root 循环存活；后台 child 写自身 PID，派生 sleep 30 孙进程并写其 PID，然后 wait。
        let script = """
        set -m
        sh -c 'echo "$$" > \(childFile); sleep 30 & echo "$!" > \(grandFile); wait' &
        while :; do sleep 0.5; done
        """
        let process = try spawnShell(script)
        let root = process.processIdentifier
        var known: [pid_t] = [root]
        defer { forceKill(known); process.waitUntilExit() }

        let child = try await waitForPID(at: childFile)
        known.append(child)
        let grand = try await waitForPID(at: grandFile)
        known.append(grand)

        let tree = TerminalProcessTree.descendantPIDs(of: root)
        #expect(tree.contains(root))
        #expect(tree.contains(child))
        #expect(tree.contains(grand))
    }

    // MARK: - #497 regression

    @Test("terminate 杀死忽略 HUP/TERM 且独立 PGID 的后台子进程（回归 #497）")
    func terminateKillsTermIgnoringBackgroundChildInOwnProcessGroup() async throws {
        let childFile = tempPath()
        defer { remove(childFile) }

        // 复现 issue：set -m 让后台 child 拥有独立 PGID；child trap "" HUP TERM 忽略优雅信号。
        let script = """
        set -m
        sh -c 'trap "" HUP TERM; echo "$$" > \(childFile); while :; do sleep 0.2; done' &
        while :; do sleep 0.2; done
        """
        let process = try spawnShell(script)
        let root = process.processIdentifier
        var known: [pid_t] = [root]
        defer { forceKill(known); process.waitUntilExit() }

        let child = try await waitForPID(at: childFile)
        known.append(child)

        // 前置：child 存活、拥有独立 PGID（与 root 不同），正是旧代码漏掉的场景。
        #expect(kill(child, 0) == 0)
        #expect(getpgid(child) == child)
        #expect(getpgid(child) != getpgid(root))

        TerminalProcessTree.terminate(root: root, gracePeriod: 0.4)

        // 宽限期后 child 必须被 SIGKILL（忽略 TERM 也活不下来），root 一并退出。
        let childDead = await waitForDeath(child, timeout: 5)
        let rootDead = await waitForDeath(root, timeout: 5)
        #expect(childDead)
        #expect(rootDead)
    }

    // MARK: - Safety

    @Test("terminate 不误杀进程树之外的无关进程")
    func terminateDoesNotKillProcessesOutsideTheTree() async throws {
        let childFile = tempPath()
        defer { remove(childFile) }

        let script = """
        set -m
        sh -c 'echo "$$" > \(childFile); while :; do sleep 0.2; done' &
        while :; do sleep 0.2; done
        """
        let process = try spawnShell(script)
        let root = process.processIdentifier
        var known: [pid_t] = [root]
        defer { forceKill(known); process.waitUntilExit() }

        let child = try await waitForPID(at: childFile)
        known.append(child)

        // 独立 bystander：不是 root 的后代，拥有自己的进程组。
        let bystander = try spawnShell("while :; do sleep 0.2; done")
        let bystanderPID = bystander.processIdentifier
        known.append(bystanderPID)
        defer { forceKill([bystanderPID]); bystander.waitUntilExit() }
        #expect(kill(bystanderPID, 0) == 0)

        TerminalProcessTree.terminate(root: root, gracePeriod: 0.4)
        _ = await waitForDeath(root, timeout: 5)
        _ = await waitForDeath(child, timeout: 5)

        // 树外进程必须存活。
        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(kill(bystanderPID, 0) == 0)
    }

    // MARK: - Helpers

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("term-tree-\(UUID().uuidString)").path
    }

    private func remove(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    private func spawnShell(_ script: String) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try process.run()
        return process
    }

    private func waitForPID(at path: String, timeout: TimeInterval = 5) async throws -> pid_t {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let text = try? String(contentsOfFile: path, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = pid_t(text), pid > 1 {
                return pid
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw TestError.pidFileTimeout(path)
    }

    private func waitForDeath(_ pid: pid_t, timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if kill(pid, 0) != 0 { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return kill(pid, 0) != 0
    }

    private func forceKill(_ pids: [pid_t]) {
        for pid in pids where pid > 1 {
            kill(pid, SIGKILL)
            if getpgid(pid) == pid { killpg(pid, SIGKILL) }
        }
    }
}