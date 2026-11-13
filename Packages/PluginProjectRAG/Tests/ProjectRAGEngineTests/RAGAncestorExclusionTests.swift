import Foundation
import Testing
@testable import ProjectRAGEngine

/// 排除目录规则只能作用于项目根「内部」：项目本身位于 `build`/`temp`/`DerivedData`
/// 等祖先目录下时，全部源码不得被祖先路径段误杀（回归 #194）。
@Suite struct RAGAncestorExclusionTests {

    /// 构造 `<tmp>/build/Demo` 项目：祖先目录名恰好命中排除列表。
    private func makeProjectUnderBuildAncestor() throws -> (container: URL, project: URL) {
        let container = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-ancestor-\(UUID().uuidString)", isDirectory: true)
        let project = container.appendingPathComponent("build/Demo", isDirectory: true)
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent("Sources", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "func zebraUniqueMarker() {}\n".write(
            to: project.appendingPathComponent("Sources/App.swift"),
            atomically: true, encoding: .utf8
        )
        // 项目内部的排除目录仍然必须被跳过。
        try FileManager.default.createDirectory(
            at: project.appendingPathComponent("build", isDirectory: true),
            withIntermediateDirectories: true
        )
        try "let junk = 1\n".write(
            to: project.appendingPathComponent("build/Junk.swift"),
            atomically: true, encoding: .utf8
        )
        return (container, project)
    }

    @Test func scannerFindsSourcesWhenProjectLivesUnderBuildAncestor() throws {
        let (container, project) = try makeProjectUnderBuildAncestor()
        defer { try? FileManager.default.removeItem(at: container) }

        let files = RAGFileScanner.discoverFiles(in: project.path)
        // 枚举器可能解析 /var → /private/var 符号链接，两侧按同一规则归一化后比较。
        let expected = project.appendingPathComponent("Sources/App.swift").path
        #expect(files.map { RAGPathUtils.normalizeProjectPath($0) }
            == [RAGPathUtils.normalizeProjectPath(expected)])
    }

    @Test func lexicalSearchFindsSourcesWhenProjectLivesUnderBuildAncestor() async throws {
        let (container, project) = try makeProjectUnderBuildAncestor()
        defer { try? FileManager.default.removeItem(at: container) }

        let results = try await RAGLexicalFileSearcher.search(
            query: "zebraUniqueMarker",
            projectPath: project.path,
            topK: 5
        )
        #expect(results.contains { $0.source == "Sources/App.swift" })
    }

    @Test func pathSearchFindsSourcesWhenProjectLivesUnderBuildAncestor() async throws {
        let (container, project) = try makeProjectUnderBuildAncestor()
        defer { try? FileManager.default.removeItem(at: container) }

        let results = try await RAGFilePathSearcher.search(
            query: "Sources/App.swift",
            projectPath: project.path,
            topK: 5
        )
        #expect(results.contains { $0.source == "Sources/App.swift" })
    }

    @Test func skipDecisionIgnoresAncestorsOutsideProjectRoot() {
        // 祖先目录命中排除列表时，项目内源码不得被误杀。
        #expect(!RAGFileScanner.shouldSkipPath(
            "/Users/alice/build/Demo/Sources/App.swift",
            projectRoot: "/Users/alice/build/Demo"
        ))
        #expect(!RAGFileScanner.shouldSkipPath(
            "/tmp/ci/temp/Demo/Sources/App.swift",
            projectRoot: "/tmp/ci/temp/Demo"
        ))
        #expect(!RAGFileScanner.shouldSkipPath(
            "/Users/alice/DerivedData-Lumi-X/Demo/Sources/App.swift",
            projectRoot: "/Users/alice/DerivedData-Lumi-X/Demo"
        ))
        // 根目录带尾斜杠时语义不变。
        #expect(!RAGFileScanner.shouldSkipPath(
            "/Users/alice/build/Demo/Sources/App.swift",
            projectRoot: "/Users/alice/build/Demo/"
        ))
        // 项目「内部」的排除目录仍然必须跳过。
        #expect(RAGFileScanner.shouldSkipPath(
            "/Users/alice/build/Demo/build/output.o",
            projectRoot: "/Users/alice/build/Demo"
        ))
        #expect(RAGFileScanner.shouldSkipPath(
            "/Users/alice/build/Demo/node_modules/pkg/index.js",
            projectRoot: "/Users/alice/build/Demo"
        ))
        #expect(RAGFileScanner.shouldSkipPath(
            "/Users/alice/build/Demo/DerivedData/Build/z.swift",
            projectRoot: "/Users/alice/build/Demo"
        ))
    }

    @Test func lexicalResultFilterUsesProjectRelativeExclusions() {
        let root = "/Users/alice/build/Demo"
        #expect(RAGLexicalFileSearcher.acceptsResultPath(
            "\(root)/Sources/App.swift", projectRoot: root
        ))
        #expect(!RAGLexicalFileSearcher.acceptsResultPath(
            "\(root)/build/Junk.swift", projectRoot: root
        ))
        #expect(!RAGLexicalFileSearcher.acceptsResultPath(
            "\(root)/Sources/notes.bin", projectRoot: root
        ))
    }
}