import Foundation
@testable import PluginProjectRAG
import KitAgentTool
import ProjectRAGEngine
import ProviderProjectRAG
import Testing

@MainActor
private final class SpacePathStubProvider: ProjectRAGProviding {
    var currentProjectPath: String?
    let isInitialized = true
    private(set) var lastSearchedProjectPath: String?

    func isIndexing(projectPath: String) -> Bool { false }

    @discardableResult
    func addProjectRAGObserver(_ callback: @escaping (ProjectRAGEvent) -> Void) -> any ProjectRAGObserverHandle {
        NoopProjectRAGObserverHandle()
    }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        lastSearchedProjectPath = projectPath
        return ProjectRAGResponse(query: query, results: [])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? { nil }
}

/// 回归 #605：search_code 过去对显式 `project_path` 做空白 trim，而 macOS
/// 目录名可以合法地以空格结尾，trim 会把检索目标改写成另一个真实存在的
/// 目录。修复后非空路径原样传递，只有空白参数才视为未提供并走回退链。
@Suite("RAGCodeSearchTool 空格路径", .serialized)
@MainActor
struct RAGCodeSearchToolSpacePathTests {

    /// 在同一父目录下创建 `base` 与 `base `（结尾带空格）两个真实目录。
    private func makeSiblingDirs() throws -> (plain: String, spaced: String, parent: URL) {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-space-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let plain = parent.appendingPathComponent("base").path
        let spaced = parent.path + "/base "
        try FileManager.default.createDirectory(atPath: plain, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(atPath: spaced, withIntermediateDirectories: false)
        return (plain, spaced, parent)
    }

    @Test("显式路径保留结尾空格并传给 provider")
    func explicitPathKeepsTrailingSpace() async throws {
        let dirs = try makeSiblingDirs()
        defer { try? FileManager.default.removeItem(at: dirs.parent) }
        let provider = SpacePathStubProvider()
        let tool = RAGCodeSearchTool(provider: provider)

        _ = try await tool.execute(arguments: [
            "query": ToolArgument("nonexistentSymbol605"),
            "project_path": ToolArgument(dirs.spaced),
        ])

        #expect(provider.lastSearchedProjectPath == dirs.spaced)
    }

    @Test("纯空白参数视为未提供，回退到会话项目")
    func whitespaceOnlyPathFallsBackToConversationProject() async throws {
        let dirs = try makeSiblingDirs()
        defer { try? FileManager.default.removeItem(at: dirs.parent) }
        let provider = SpacePathStubProvider()
        let tool = RAGCodeSearchTool(provider: provider)

        _ = try await tool.execute(
            arguments: [
                "query": ToolArgument("nonexistentSymbol605"),
                "project_path": ToolArgument("   "),
            ],
            conversationProjectPath: dirs.plain,
            conversationID: nil
        )

        #expect(provider.lastSearchedProjectPath == dirs.plain)
    }

    @Test("空白参数且无回退项目时仍然报错")
    func whitespaceOnlyPathWithoutFallbackThrows() async {
        ProjectRAGRuntime.reset()
        await #expect(throws: ToolExecutionError.self) {
            _ = try await RAGCodeSearchTool().execute(arguments: [
                "query": ToolArgument("nonexistentSymbol605"),
                "project_path": ToolArgument("   "),
            ])
        }
    }
}
