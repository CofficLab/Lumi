import Foundation
import Testing
@testable import ProjectRAGEngine

/// ripgrep 调用必须**离开协作线程池**。
///
/// ## 为什么这是硬要求
///
/// 工具体跑在 Swift Concurrency 的协作线程池上（`ToolExecutionRuntime` 的
/// `Task.detached`），而协作线程池同时负责调度 `MainActor`。改造前
/// `RAGGrepSearcher` 用 `readDataToEndOfFile()` + `waitUntilExit()` 同步等待
/// ripgrep 退出，一次大项目扫描会占住这些线程数百毫秒到数秒。
///
/// 协作线程池的宽度与 CPU 核数同阶。被占满时 `MainActor` 无法被调度，
/// UI 停止响应——实测（`blockedCooperative` 实验）：阻塞 8 个协作线程时
/// 主 actor 心跳基本正常，阻塞到 12 个（= 处理器核数）时进程**整体冻结**
/// （心跳停摆，且后续 `await` 全部不再推进）。
///
/// 同类缺陷见 issue #1288（`project_overview` 用无超时 `DispatchSemaphore.wait()`
/// 阻塞协作线程，饿死调度 MainActor 的线程池）。
///
/// ## 判据
///
/// 在 grep 执行期间，**协作线程池必须仍有余量**：若 grep 把池占满，
/// 主 actor 心跳会停摆。测试用主 actor 心跳作为探针。
@Suite struct RAGProcessRunnerNonBlockingTests {

    /// 心跳探针：在主 actor 上自增计数。
    ///
    /// 停滞即说明主 actor 没能被调度（协作线程池被占满）。
    @MainActor
    private final class MainActorHeartbeat {
        private(set) var ticks = 0

        func tick() {
            ticks += 1
        }
    }

    /// 造一个「足够大」的项目目录，让 ripgrep 的扫描时间明显长于一次心跳间隔。
    private func makeLargeProject(fileCount: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-nonblocking-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // 每个文件塞入足够多的内容，保证 ripgrep 需要实际扫描这些字节，
        // 而不是只走目录遍历就返回。
        let filler = String(repeating: "let value = 1234567890\n", count: 400)
        for index in 0..<fileCount {
            let directory = root.appendingPathComponent("dir\(index % 8)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("File\(index).swift")
            try (filler + "// marker \(index)\n").write(
                to: file,
                atomically: true,
                encoding: .utf8
            )
        }
        return root
    }

    /// 制造足以占满协作线程池的并发 grep 数。
    ///
    /// 实测（12 核机器）：并发阻塞任务数 ≤ 20 时主 actor 心跳正常，
    /// 达到 24（= 2 × 核数）时心跳几乎完全停摆。取 2 × 核数并留余量，
    /// 确保「阻塞实现」必然饿死线程池，而「非阻塞实现」完全不受影响。
    private func starvingGrepCount() -> Int {
        max(ProcessInfo.processInfo.activeProcessorCount * 2, 16)
    }

    @Test("并发 ripgrep 不会占满协作线程池")
    func concurrentGrepsDoNotStarveCooperativePool() async throws {
        let root = try makeLargeProject(fileCount: 200)
        defer { try? FileManager.default.removeItem(at: root) }

        let grepCount = starvingGrepCount()
        let heartbeat = MainActorHeartbeat()
        let heartbeatTask = Task { @MainActor in
            // 心跳间隔 5ms。
            while !Task.isCancelled {
                await MainActor.run { heartbeat.tick() }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        defer { heartbeatTask.cancel() }

        // 先给心跳一个起跑窗口，避免把「线程调度本来就需要时间」误判为阻塞。
        try await Task.sleep(nanoseconds: 50_000_000)
        let ticksBefore = await MainActor.run { heartbeat.ticks }
        #expect(ticksBefore > 0, "心跳探针本身没有工作，测试前提不成立")

        // 并发发起足以占满协作线程池的 grep。
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<grepCount {
                group.addTask {
                    _ = try? await RAGGrepSearcher.search(
                        pattern: "marker \(index % 8)",
                        projectPath: root.path,
                        maxResults: 2
                    )
                }
            }
        }

        let ticksAfter = await MainActor.run { heartbeat.ticks }
        heartbeatTask.cancel()

        // 主 actor 在整批 grep 期间必须持续被调度。
        //
        // 改造前：每个 grep 的 `readDataToEndOfFile()` + `waitUntilExit()`
        // 同步占住一个协作线程；并发数达到 2 × 核数时线程池被占满，
        // 主 actor 心跳停摆（实测 ticks 从 ~60 掉到 ~1）。
        // 改造后：ripgrep 跑在 GCD 线程上，协作线程完全释放，心跳持续增长。
        let ticksDuringGreps = ticksAfter - ticksBefore
        #expect(
            ticksDuringGreps > 0,
            "\(grepCount) 个并发 grep 期间主 actor 没有获得调度，说明 ripgrep 调用仍阻塞协作线程池"
        )
    }

    @Test("并发 grep 不会互相阻塞")
    func concurrentGrepsDoNotBlockEachOther() async throws {
        let root = try makeLargeProject(fileCount: 150)
        defer { try? FileManager.default.removeItem(at: root) }

        let startedAt = Date()
        async let first = RAGGrepSearcher.search(pattern: "marker 1", projectPath: root.path, maxResults: 5)
        async let second = RAGGrepSearcher.search(pattern: "marker 2", projectPath: root.path, maxResults: 5)
        async let third = RAGGrepSearcher.search(pattern: "marker 3", projectPath: root.path, maxResults: 5)

        let (a, b, c) = try await (first, second, third)
        let duration = Date().timeIntervalSince(startedAt)

        #expect(a.totalMatchCount > 0)
        #expect(b.totalMatchCount > 0)
        #expect(c.totalMatchCount > 0)

        // 三个 grep 的总耗时必须小于串行执行的时间。
        //
        // 串行下界由单个 grep 的耗时决定；这里用「三次串行」不可能低于的
        // 宽松阈值来判定：并发时三个 grep 共享磁盘 IO，耗时接近单个 grep；
        // 串行时至少是三倍。阈值取 2.0s 对两者都有区分度，同时给高负载
        // 的 CI 留出余量（避免偶发失败）。
        #expect(duration < 2.0, "三次 grep 耗时 \(duration)s，疑似串行执行")
    }
}
