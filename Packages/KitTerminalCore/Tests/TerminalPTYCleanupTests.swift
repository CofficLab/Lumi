import AppKit
import Darwin
import Testing
@testable import KitTerminalCore

@Suite("自然退出后关闭 PTY IO")
@MainActor
struct TerminalPTYCleanupTests {
    @Test("进程自然退出后 PTY master fd 被释放（回归 #175）")
    func naturalExitClosesPTYFileDescriptor() async throws {
        let view = LumiTerminalView(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        let baseline = openFileDescriptorCount()

        view.startProcess(
            executable: "/bin/sleep",
            args: ["0"],
            environment: nil,
            execName: "sleep",
            currentDirectory: nil
        )

        // 等 EOF（running 翻转发生在监控回调之前）。
        var exited = false
        for _ in 0..<100 {
            if view.process?.running == false {
                exited = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(exited, "sleep 0 应自然退出")

        // 修复后的关闭发生在自然退出的监控回调里，且 DispatchIO 的 cleanup
        // handler 异步关 fd：轮询直到回到基线。修复前 master fd 永远多一个。
        var released = false
        for _ in 0..<50 {
            if openFileDescriptorCount() <= baseline {
                released = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(released, "自然退出后 PTY master fd 必须被释放（回归 #175）")
    }
}

/// 测试进程自身的打开 fd 数。
private func openFileDescriptorCount() -> Int {
    let needed = proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, nil, 0)
    guard needed > 0 else { return .max }
    let capacity = Int(needed) / MemoryLayout<proc_fdinfo>.size + 16
    var buffer = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
    let written = buffer.withUnsafeMutableBytes { raw in
        proc_pidinfo(getpid(), PROC_PIDLISTFDS, 0, raw.baseAddress, Int32(raw.count))
    }
    guard written > 0 else { return .max }
    return Int(written) / MemoryLayout<proc_fdinfo>.size
}
