import Foundation
@testable import PluginProjectRAG
import KernelCore
import KitAgentTool
import KitLLM
import ProjectRAGEngine
import ProviderLifecycleHooks
import ProviderIdleTime
import ProviderProject
import ProviderProjectRAG
import ProviderStorage
import Testing

@Suite("ProjectRAGPlugin")
@MainActor
struct ProjectRAGSuperPluginTests {
    @Test("keeps the legacy plugin and tool identifiers")
    func retainsStableIdentifiers() {
        #expect(ProjectRAGPlugin().id == "com.coffic.lumi.plugin.project.rag")
        #expect(RAGCodeSearchTool.toolName == "search_code")
        #expect(RAGGrepTool.toolName == "grep")
    }

    @Test("registers the RAG capability in KernelCore")
    func registersProvider() throws {
        let kernel = KernelCoreContainer()
        // 注入**独立**的存储目录。
        //
        // - Important: 不注入时 `onBoot` 会回退到
        //   `FileManager.default.temporaryDirectory/<pluginID>` ——
        //   **所有插件用例共用同一个目录**，于是共用同一个 `rag.sqlite`。
        //   SwiftData/SQLite 的 initialize 会互相等待：高负载下（CI 上
        //   多个包同时跑）本用例的 `initialize` 超时 → `scheduler` 为 nil
        //   → 断言失败。**偶发，且与被测行为无关。**
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-plugin-\(UUID().uuidString)", isDirectory: true)
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: storageRoot)
        )
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let plugin = ProjectRAGPlugin()

        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectRAGProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectRAGProviding).self) == nil)
    }

    private func makeContext(projectPath: String?) -> KitAgentTool.ToolExecutionContext {
        KitAgentTool.ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
    }

    private func missingPath(_ name: String) -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-\(name)-\(UUID().uuidString)")
            .path
    }

    @Test("search_code 未传 project_path 时使用会话绑定项目")
    func usesConversationProject() async throws {
        let conversationPath = missingPath("conversation")

        do {
            _ = try await RAGCodeSearchTool().executeResult(
                context: makeContext(projectPath: conversationPath),
                arguments: ["query": ToolArgument("handleRequest")]
            )
            Issue.record("expected ToolExecutionError for nonexistent project path")
        } catch let error as ToolExecutionError {
            guard case let .executionFailed(_, reason) = error else {
                Issue.record("unexpected ToolExecutionError case: \(error)")
                return
            }
            #expect(reason.contains(conversationPath))
        }
    }

    @Test("search_code 显式 project_path 优先于会话绑定项目")
    func explicitPathBeatsConversationProject() async throws {
        let conversationPath = missingPath("conversation")
        let explicitPath = missingPath("explicit")

        do {
            _ = try await RAGCodeSearchTool().executeResult(
                context: makeContext(projectPath: conversationPath),
                arguments: [
                    "query": ToolArgument("handleRequest"),
                    "project_path": ToolArgument(explicitPath),
                ]
            )
            Issue.record("expected ToolExecutionError for nonexistent project path")
        } catch let error as ToolExecutionError {
            guard case let .executionFailed(_, reason) = error else {
                Issue.record("unexpected ToolExecutionError case: \(error)")
                return
            }
            #expect(reason.contains(explicitPath))
            #expect(!reason.contains(conversationPath))
        }
    }
}

@MainActor
private final class StubProjectRAGProvider: ProjectRAGProviding {
    var currentProjectPath: String? = "/tmp/Lumi"
    let isInitialized = true
    var indexing = false
    var ensureIndexedCallCount = 0
    var lastEnsureIndexedBackground: Bool?
    var searchCallCount = 0
    var response = ProjectRAGResponse(
        query: "",
        results: [
            ProjectRAGSearchResult(
                content: "func handleRequest() {}",
                source: "Sources/Feature.swift",
                score: 0.9,
                matchKind: .semantic,
                lineRange: ProjectRAGLineRange(startLine: 12, endLine: 19)
            ),
        ]
    )

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func isIndexing(projectPath: String) -> Bool {
        indexing
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        searchCallCount += 1
        return response
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {
        ensureIndexedCallCount += 1
        lastEnsureIndexedBackground = background
    }

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        nil
    }
}

@Suite("ProjectRAGLLMContextHook")
@MainActor
struct ProjectRAGLLMContextHookTests {
    @Test("同一回合后续请求复用缓存证据，不重复检索（回归 #604）")
    func reinjectsEvidenceForSameTurnWithoutResearching() async {
        let provider = StubProjectRAGProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "这个项目的代码怎么实现请求处理")],
            conversationID: UUID()
        )

        let first = await hook.apply(to: context)
        let second = await hook.apply(to: context)
        let otherContext = WillSendToLLMContext(
            messages: context.messages,
            conversationID: UUID()
        )
        let other = await hook.apply(to: otherContext)

        #expect(first.messages.count == context.messages.count + 1)
        #expect(first.messages.first?.role == .system)
        #expect(first.messages.first?.content.contains("Sources/Feature.swift:12-19") == true)
        // #604：输入历史不含证据时，同一回合的后续请求必须补回缓存证据，而非早退丢弃。
        #expect(second.messages.count == context.messages.count + 1)
        #expect(second.messages.first?.content.contains("Sources/Feature.swift:12-19") == true)
        #expect(other.messages.count == otherContext.messages.count + 1)
        // 复用缓存不触发新检索：仅 first 与 other（不同会话）各检索一次。
        #expect(provider.searchCallCount == 2)
        #expect(provider.ensureIndexedCallCount == 2)
        #expect(provider.lastEnsureIndexedBackground == false)
    }

    @Test("does not query RAG for casual conversation")
    func skipsCasualConversation() async {
        let provider = StubProjectRAGProvider()
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "hello, how are you today")],
            conversationID: UUID()
        )

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
        #expect(provider.ensureIndexedCallCount == 0)
    }

    @Test("does not wait for RAG while the project is indexing")
    func skipsIndexingProject() async {
        let provider = StubProjectRAGProvider()
        provider.indexing = true
        let hook = ProjectRAGLLMContextHook(provider: provider)
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "了解这个项目的代码")],
            conversationID: UUID()
        )

        let result = await hook.apply(to: context)

        #expect(result.messages == context.messages)
        #expect(provider.ensureIndexedCallCount == 0)
        #expect(provider.searchCallCount == 0)
    }
}

@Suite("RAGCodeSearchTool")
@MainActor
struct RAGCodeSearchToolTests {
    @Test("includes line evidence in tool output")
    func includesLineEvidence() async throws {
        let provider = StubProjectRAGProvider()
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-tool-output-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let output = try await RAGCodeSearchTool(provider: provider).execute(arguments: [
            "query": ToolArgument("handleRequest"),
            "project_path": ToolArgument(projectURL.path),
        ])

        #expect(output.contains("Sources/Feature.swift:12-19"))
        #expect(output.contains("evidence: semantic"))
        #expect(output.contains("func handleRequest() {}"))
    }

    @Test("suppresses an immediate duplicate after automatic injection")
    func suppressesImmediateDuplicate() async throws {
        let provider = StubProjectRAGProvider()
        let searchMemory = ProjectRAGSearchMemory()
        let hook = ProjectRAGLLMContextHook(provider: provider, searchMemory: searchMemory)
        let conversationID = UUID()
        let context = WillSendToLLMContext(
            messages: [LLMMessage(role: .user, content: "这个项目的代码怎么实现请求处理")],
            conversationID: conversationID
        )
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-tool-dedup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }
        provider.currentProjectPath = projectURL.path

        _ = await hook.apply(to: context)
        // 同一对话紧接着的真实 search_code 才消费抑制标记（#467）。
        let toolContext = ToolExecutionContext(jobID: "job-dedup", conversationID: conversationID)
        let output = try await RAGCodeSearchTool(provider: provider, searchMemory: searchMemory)
            .executeResult(context: toolContext, arguments: [
                "query": ToolArgument("这个项目的代码怎么实现请求处理"),
                "project_path": ToolArgument(projectURL.path),
            ]).content

        #expect(output.contains("already injected"))
        #expect(provider.searchCallCount == 1)
    }
}

@Suite("CodeNavigationCoordinator")
@MainActor
struct CodeNavigationCoordinatorTests {
    @Test("does not enqueue semantic search while indexing")
    func skipsSemanticSearchDuringIndexing() async throws {
        let provider = StubProjectRAGProvider()
        provider.indexing = true
        let coordinator = CodeNavigationCoordinator(provider: provider)

        let response = try await coordinator.search(
            query: "了解这个项目的代码",
            projectPath: "/tmp/Lumi",
            topK: 8
        )

        #expect(response.query == "了解这个项目的代码")
        #expect(response.results.isEmpty)
        #expect(provider.ensureIndexedCallCount == 0)
        #expect(provider.searchCallCount == 0)
    }

    @Test("indexes a missing project before searching")
    func indexesMissingProjectBeforeSearching() async throws {
        let provider = StubProjectRAGProvider()
        let coordinator = CodeNavigationCoordinator(provider: provider)

        let response = try await coordinator.search(
            query: "handleRequest",
            projectPath: "/tmp/Lumi",
            topK: 8
        )

        #expect(response.results.count == 1)
        #expect(provider.ensureIndexedCallCount == 1)
        #expect(provider.lastEnsureIndexedBackground == false)
        #expect(provider.searchCallCount == 1)
    }

    @Test("merges semantic and exact file evidence")
    func mergesSemanticAndExactFileEvidence() async throws {
        let provider = StubProjectRAGProvider()
        let coordinator = CodeNavigationCoordinator(provider: provider)
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-coordinator-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = projectURL.appendingPathComponent("Sources/Router.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "func routeRequest() {}".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let response = try await coordinator.search(
            query: "routeRequest",
            projectPath: projectURL.path,
            topK: 8
        )

        #expect(response.results.contains { result in
            result.source == "Sources/Router.swift" && result.matchKind == .filesystemLexical
        })
    }

    @Test("merges explicit file path evidence")
    func mergesExplicitFilePathEvidence() async throws {
        let provider = StubProjectRAGProvider()
        let coordinator = CodeNavigationCoordinator(provider: provider)
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-coordinator-path-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = projectURL.appendingPathComponent("Sources/Router.swift")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "let unrelatedValue = true".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let response = try await coordinator.search(
            query: "Sources/Router.swift",
            projectPath: projectURL.path,
            topK: 8
        )

        #expect(response.results.contains { result in
            result.source == "Sources/Router.swift" && result.matchKind == .filesystemPath
        })
    }
}

@MainActor
private final class StubProjectProvider: ProjectProviding {
    var currentProject: ProjectInfo?
    var projects: [ProjectInfo]
    var openFileURLs: [URL] = []
    var currentFileURL: URL?

    init(currentProject: ProjectInfo?, projects: [ProjectInfo] = []) {
        self.currentProject = currentProject
        self.projects = projects
    }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        currentProject = ProjectInfo(name: path, path: path)
    }

    func updateCurrentFile(_ fileURL: URL?) {
        currentFileURL = fileURL
    }

    func updateOpenFiles(_ fileURLs: [URL]) {
        openFileURLs = fileURLs
    }

    func closeFile(_ fileURL: URL) {
        openFileURLs.removeAll { $0 == fileURL }
    }

    func closeProject(reason: ProjectChangeReason) async {
        currentProject = nil
    }

    func refreshProjects() async throws {}

    func synchronizeProjects(_ projects: [ProjectInfo]) {
        self.projects = projects
    }
}

/// Regression coverage for issue #925: launching without a current project used
/// to return from the boot task before the idle scheduler ever started, so RAG
/// indexing stayed disabled for the whole session.
@Suite("ProjectRAGPlugin 启动调度")
@MainActor
struct ProjectRAGBootSchedulingTests {

    @Test("启动时没有当前项目也会启动 idle 调度")
    func startsIdleSchedulerWithoutCurrentProject() async throws {
        let kernel = KernelCoreContainer()
        let project = StubProjectProvider(
            currentProject: nil,
            projects: [ProjectInfo(name: "known", path: "/tmp/known-project")]
        )
        try kernel.registerProvider((any ProjectProviding).self, project)
        try kernel.registerProvider((any IdleTimeProviding).self, DefaultIdleTimeProviding())

        // 其他插件用例也会启动基于默认临时目录的 RAGService；共用同一个
        // SQLite 文件会让本用例的 initialize 与它们互相等待。
        let storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-boot-\(UUID().uuidString)", isDirectory: true)
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: storageRoot)
        )
        defer { try? FileManager.default.removeItem(at: storageRoot) }

        let plugin = ProjectRAGPlugin()
        try plugin.onBoot(kernel: kernel)

        for _ in 0..<200 where plugin.scheduler == nil {
            try await Task.sleep(for: .milliseconds(25))
        }

        #expect(project.currentProject == nil)
        #expect(plugin.scheduler != nil, "没有当前项目时 idle 调度没有启动")

        try plugin.onShutdown(kernel: kernel)
        #expect(plugin.scheduler == nil)
    }
}

/// Regression coverage for issue #1065: the provider used to retain every
/// registered callback even after its handle was released, so repeated
/// settings re-renders left dead callbacks behind forever.
@Suite("ProjectRAGProvider 观察者生命周期")
@MainActor
struct ProjectRAGProviderObserverLifetimeTests {
    private func makeProvider() -> ProjectRAGProvider {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-provider-\(UUID().uuidString)", isDirectory: true)
        return ProjectRAGProvider(
            service: RAGService(databaseDirectoryProvider: { directory }),
            project: nil
        )
    }

    @Test("释放 handle 后不再收到事件")
    func releasedHandleStopsReceivingEvents() {
        let provider = makeProvider()
        var events = 0
        var handle: (any ProjectRAGObserverHandle)? = provider.addProjectRAGObserver { _ in
            events += 1
        }

        provider.handleProjectChange()
        #expect(events == 1)

        handle = nil
        provider.handleProjectChange()
        #expect(events == 1, "释放 handle 后回调仍被 Provider 调用")
    }

    @Test("释放 handle 后回调捕获的值可以释放")
    func releasingHandleReleasesCallbackCapture() {
        let provider = makeProvider()
        var capture: CallbackCapture? = CallbackCapture()
        weak var weakCapture = capture
        var handle: (any ProjectRAGObserverHandle)? = provider.addProjectRAGObserver { [capture] _ in
            _ = capture
        }

        capture = nil
        #expect(weakCapture != nil, "handle 存活时回调应持有其捕获值")

        handle = nil
        #expect(weakCapture == nil, "handle 释放后 Provider 仍强持有回调")
    }

    @Test("cancel 立即注销观察者")
    func cancelRemovesObserver() {
        let provider = makeProvider()
        var events = 0
        let handle = provider.addProjectRAGObserver { _ in
            events += 1
        }

        provider.handleProjectChange()
        handle.cancel()
        provider.handleProjectChange()
        #expect(events == 1, "cancel 之后仍收到事件")
    }
}

private final class CallbackCapture {}

/// 包内共享的存储替身：把插件数据目录指向**调用方提供的独立根目录**。
///
/// - Important: 插件在拿不到 `StorageProviding` 时会回退到
///   `FileManager.default.temporaryDirectory/<pluginID>` —— 那是**所有用例
///   共用**的目录，于是共用同一个 `rag.sqlite`，多个用例的 initialize
///   互相等待，高负载下会偶发超时。注入独立根目录可彻底隔离。
final class StubStorageProvider: StorageProviding {
    let dataRootDirectory: URL

    init(root: URL) {
        dataRootDirectory = root
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory
    }
}

/// Regression coverage for issue #1063: the automatic-injection dedup used to
/// keep the full user message text forever. It now stores only a fixed-size
/// digest and remembers a bounded number of recent turns.
@Suite("RAGInjectionDeduplication")
struct RAGInjectionDeduplicationTests {
    private func key(_ content: String, conversationID: UUID = UUID(), userMessageCount: Int = 1) -> RAGInjectionDeduplication.Key {
        RAGInjectionDeduplication.Key(
            conversationID: conversationID,
            userMessageCount: userMessageCount,
            content: content
        )
    }

    @Test("去重键只保存固定长度摘要")
    func keyStoresOnlyDigest() {
        let content = "SECRET - full user message body"
        let conversationID = UUID()
        let first = key(content, conversationID: conversationID)
        let second = key(content, conversationID: conversationID)

        #expect(first.contentDigest.count == 64)
        #expect(!first.contentDigest.contains("SECRET"))
        #expect(first == second)
        #expect(first != key(content, conversationID: UUID()))
        #expect(first != key(content, conversationID: conversationID, userMessageCount: 2))
    }

    @Test("超过容量后淘汰最旧的回合")
    func evictsOldestTurnBeyondCapacity() {
        var dedup = RAGInjectionDeduplication(capacity: 2)
        let first = key("first")
        let second = key("second")
        let third = key("third")

        dedup.record(first)
        dedup.record(second)
        #expect(dedup.keys.count == 2)
        #expect(dedup.contains(first))
        #expect(dedup.contains(second))

        dedup.record(third)
        #expect(dedup.keys.count == 2)
        #expect(!dedup.contains(first), "窗口应淘汰最旧的回合")
        #expect(dedup.contains(second))
        #expect(dedup.contains(third))
    }

    @Test("重复记录同一回合不会扩大窗口")
    func recordingSameTurnIsIdempotent() {
        var dedup = RAGInjectionDeduplication(capacity: 2)
        let turn = key("same turn")

        dedup.record(turn)
        dedup.record(turn)
        dedup.record(key("another turn"))

        #expect(dedup.keys.count == 2)
        #expect(dedup.contains(turn))
    }

    @Test("缓存的注入证据随回合淘汰一起清除（回归 #604）")
    func evidenceEvictedWithTurn() {
        var dedup = RAGInjectionDeduplication(capacity: 2)
        let first = key("first")
        let second = key("second")
        let third = key("third")

        dedup.record(first, content: "evidence-1")
        dedup.record(second, content: "evidence-2")
        #expect(dedup.content(for: first) == "evidence-1")
        #expect(dedup.content(for: second) == "evidence-2")

        dedup.record(third, content: "evidence-3")
        #expect(dedup.content(for: first) == nil, "淘汰回合时其证据也必须清除")
        #expect(dedup.content(for: second) == "evidence-2")
        #expect(dedup.content(for: third) == "evidence-3")
    }
}
