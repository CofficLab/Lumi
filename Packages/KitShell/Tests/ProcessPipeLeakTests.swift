import Testing
import Foundation
import Darwin
@testable import KitShell

/// 统计当前进程打开的文件描述符数量。
///
/// 使用 `proc_pidinfo(PROC_PIDLISTFDS)`：它只报告本进程已打开的 fd，
/// **自身不需要新建 fd**，因此即便 fd 接近上限时也能安全调用。
enum PipeFDProbe {

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
}

/// 复现并锁定 `Foundation.Pipe`（`NSPipe`）的文件描述符泄漏。
///
/// ## 根因
///
/// `Pipe` 创建时占用 2 个 fd（读端 + 写端），其释放依赖 autorelease pool 排空
/// 或对象析构。当 `Process` + `Pipe` 在**同一个 autorelease pool 内被同步反复创建**
/// 时（chat/agent 主线程热路径在长回合内不排空 pool，正是这种形态），这些 fd 会
/// 在 pool 排空前持续堆积。长时间对话后耗尽进程 fd 上限，`URLSession` 无法新建
/// socket，报 `Too many open files` (EMFILE)——表现为「聊得越久越容易报网络错误」。
///
/// ## 测量方式
///
/// 关键：必须在 **`autoreleasepool` 内部**测量。pool 一旦排空，未关闭的管道 fd 也会
/// 被回收，就测不到累积。本套件把「执行 N 次」和「测量」都放在同一个显式 pool 内。
///
/// ## 修复
///
/// 每个管道使用结束后必须**显式关闭两端 fd**（`Pipe.closeFileDescriptors()`），
/// 而不是等待 ARC/autorelease。这样即便 pool 长时间不排空，fd 也会立即归还进程。
@Suite("Process Pipe FD Leak", .serialized)
struct ProcessPipeLeakTests {

    /// 一次「启动子进程并读取管道」的调用。
    ///
    /// - Parameter closePipes: 是否按修复要求显式关闭管道 fd。
    private static func runProcess(closePipes: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/echo")
        process.arguments = ["lumi"]
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        guard (try? process.run()) != nil else {
            if closePipes {
                stdoutPipe.closeFileDescriptors()
                stderrPipe.closeFileDescriptors()
            }
            return
        }
        _ = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        _ = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if closePipes {
            stdoutPipe.closeFileDescriptors()
            stderrPipe.closeFileDescriptors()
        }
    }

    /// 在**单个 autorelease pool 内**执行 N 次 `Process` + `Pipe`，并在 pool 内测量 fd 增长。
    ///
    /// - Returns: `(growth, iterations)`，growth 为 pool 内的 fd 相对增长量。
    private static func fdGrowthInsidePool(iterations: Int, closePipes: Bool) -> Int {
        var growth = 0
        autoreleasepool {
            // 预热一轮，排除一次性资源（动态库、locale 等）的干扰。
            for _ in 0..<3 { runProcess(closePipes: closePipes) }
            let baseline = PipeFDProbe.openCount()

            for _ in 0..<iterations { runProcess(closePipes: closePipes) }

            // 仍在 pool 内：未关闭的管道对象尚未析构，泄漏在此可见。
            growth = PipeFDProbe.openCount() - baseline
        }
        return growth
    }

    /// 主回归用例：显式关闭管道后，即使 pool 未排空，fd 也不随调用次数累积。
    @Test("显式关闭管道后，pool 内反复创建 Process+Pipe 不累积 fd")
    func explicitCloseDoesNotAccumulateFileDescriptors() {
        let iterations = 60
        let growth = Self.fdGrowthInsidePool(iterations: iterations, closePipes: true)

        // 每轮 4 个管道 fd；若未释放会增长约 240。关闭后应基本持平。
        #expect(
            growth <= 8,
            """
            pool 内 \(iterations) 次 Process+Pipe 后 fd 增长了 \(growth)。
            预期显式关闭 `Pipe` 两端 fd 后，fd 不随调用次数累积。
            """
        )
    }

    /// 根因对照组：不关闭管道 fd 时，pool 内会明显累积。
    ///
    /// 该用例保证测量本身对泄漏敏感——若修复被回退（去掉 `closeFileDescriptors()`），
    /// 上面的回归用例会失败，而这里证明它能被测出来。
    @Test("不关闭管道时 fd 在 pool 内累积（根因对照组）")
    func unclosedPipesAccumulateInsidePool() {
        let iterations = 60
        let growth = Self.fdGrowthInsidePool(iterations: iterations, closePipes: false)

        // 每个 `Pipe` 读 + 写两端共 2 个 fd，两处管道即 4 个。
        #expect(
            growth >= iterations * 2,
            """
            未关闭管道时预期 fd 明显累积，实际增长 \(growth)。
            该对照组用于说明：不显式关闭 `Pipe` 会导致每个管道滞留 2 个 fd。
            """
        )
    }

    /// 端到端:真实工具调用路径(`ShellExecutor`)反复执行后 fd 不增长。
    ///
    /// 覆盖 agent 会话中最高频的子进程调用点。注意:ShellExecutor 内部使用
    /// `Task.detached` 在 GCD 队列上执行,GCD 自带 per-block autorelease pool,
    /// 所以即使不显式关闭管道也不会泄漏。此测试主要作为端到端健全性检查,
    /// 真正的泄漏守卫在 `explicitCloseDoesNotAccumulateFileDescriptors` 和
    /// `unclosedPipesAccumulateInsidePool` 中。
    @Test("ShellExecutor 反复执行后 fd 不增长(端到端健全性)")
    func shellExecutorRepeatedExecutionDoesNotLeak() async throws {
        _ = try? await ShellExecutor.execute("/bin/echo warmup", options: .init(throwsOnError: false))
        try await Task.sleep(nanoseconds: 300_000_000)
        let baseline = PipeFDProbe.openCount()
        #expect(baseline > 0, "fd 计数应可用")

        for _ in 0..<40 {
            _ = try? await ShellExecutor.execute(
                "/bin/echo lumi-fd-check",
                options: .init(throwsOnError: false)
            )
            _ = try? await ShellExecutor.execute(
                "/bin/sh -c 'echo out; echo err 1>&2'",
                options: .init(throwsOnError: false)
            )
        }
        try await Task.sleep(nanoseconds: 500_000_000)

        let growth = PipeFDProbe.openCount() - baseline
        #expect(
            growth <= 8,
            """
            80 次 ShellExecutor 调用后 fd 增长了 \(growth)（基线 \(baseline)）。
            工具调用路径不应随调用次数累积 fd。
            """
        )
    }
}
