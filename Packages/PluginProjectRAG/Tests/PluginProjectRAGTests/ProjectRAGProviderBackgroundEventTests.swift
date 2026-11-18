import Foundation
import ProjectRAGEngine
import ProviderProjectRAG
import Testing
@testable import PluginProjectRAG

/// 回归 #195：后台索引的完成事件过去在任务**排队瞬间**就发出——
/// `ensureIndexedBackground` 排队即返回，Provider 紧接着同步 `notify(.indexingFinished)`，
/// 观察者收到事件时真实索引甚至尚未开始，读不到最终索引状态。
///
/// 修复后 Provider 派发一个 watcher 任务，经 `RAGService.waitForBackgroundIndexing`
/// 等待后台任务真正结束（成功或失败）后才发出完成事件。
///
/// 用例一的判据是零调度假设的：旧实现里 `notify` 在 `ensureIndexed` 调用**内部**
/// 同步执行（观察者回调先于 `ensureIndexed` 返回）；新实现的 watcher 要先经过
/// service actor 与真实索引才能把事件送回主 actor，事件必然晚于返回。
@Suite("ProjectRAGProvider 后台索引事件", .serialized)
@MainActor
struct ProjectRAGProviderBackgroundEventTests {

    /// 建一个含单个 Swift 文件的临时「项目」及其独立数据库目录。
    private func makeFixture() throws -> (project: URL, database: URL) {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-bg-event-project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "func backgroundEventFeature() {}\n".write(
            to: project.appendingPathComponent("Feature.swift"),
            atomically: true,
            encoding: .utf8
        )
        let database = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-bg-event-db-\(UUID().uuidString)", isDirectory: true)
        return (project, database)
    }

    @Test("完成事件必须在 ensureIndexed 返回之后才发出", .timeLimit(.minutes(2)))
    func finishedEventArrivesOnlyAfterEnsureIndexedReturns() async throws {
        let (project, database) = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: project)
            try? FileManager.default.removeItem(at: database)
        }

        let service = RAGService(databaseDirectoryProvider: { database })
        let provider = ProjectRAGProvider(service: service, project: nil)

        // finished 送达时记录 ensureIndexed 是否已经返回：
        // 旧实现在调用内部同步 notify → false；新实现由 watcher 延迟发送 → true。
        var callReturned = false
        var returnedAtFinish: Bool?
        // 句柄必须持有：释放后弱引用观察者会在 notify 时被清理（观察者生命周期语义）。
        let observer = provider.addProjectRAGObserver { event in
            if case .indexingFinished = event {
                returnedAtFinish = callReturned
            }
        }
        defer { observer.cancel() }

        try await provider.ensureIndexed(projectPath: project.path, force: false, background: true)
        callReturned = true

        // 等待完成事件送达（watcher 在真实索引结束后发出）。
        for _ in 0..<400 where returnedAtFinish == nil {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(returnedAtFinish != nil, "完成事件未送达")
        #expect(returnedAtFinish == true, "完成事件在 ensureIndexed 返回之前就发出了")
    }

    @Test("完成事件送达后观察者能读到最终索引状态", .timeLimit(.minutes(2)))
    func observerCanReadFinalStateAfterFinishedEvent() async throws {
        let (project, database) = try makeFixture()
        defer {
            try? FileManager.default.removeItem(at: project)
            try? FileManager.default.removeItem(at: database)
        }

        let service = RAGService(databaseDirectoryProvider: { database })
        let provider = ProjectRAGProvider(service: service, project: nil)

        var finishedPath: String?
        let observer = provider.addProjectRAGObserver { event in
            if case .indexingFinished(let path) = event {
                finishedPath = path
            }
        }
        defer { observer.cancel() }

        try await provider.ensureIndexed(projectPath: project.path, force: false, background: true)

        // 完成事件送达后，索引状态必须可读（事件不会再先于索引结束到达）。
        for _ in 0..<400 where finishedPath == nil {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(finishedPath == project.path)

        var status: ProjectRAGIndexStatus?
        for _ in 0..<100 where status == nil {
            status = try await provider.indexStatus(projectPath: project.path)
            if status == nil {
                try await Task.sleep(for: .milliseconds(25))
            }
        }
        #expect(status != nil, "完成事件送达后仍读不到索引状态")
        #expect(status?.fileCount == 1)
    }
}
