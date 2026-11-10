import Foundation
import Testing
@testable import ProjectRAGEngine

/// 词法搜索必须与索引扫描/路径搜索看到同一组源码，不能因为 `.gitignore` 而漏文件。
@Suite struct RAGLexicalIgnoreTests {

    private func makeProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-lexical-ignore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func gitInit(_ root: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init", "--quiet", root.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
    }

    @Test func ripgrepArgumentsDisableIgnoreRules() throws {
        let arguments = RAGLexicalFileSearcher.ripgrepArguments(
            terms: ["needle"],
            projectPath: "/tmp/project"
        )
        #expect(arguments.contains("--no-ignore"))
        #expect(arguments.last == "/tmp/project")
    }

    @Test func lexicalSearchFindsSourceInGitignoredDirectory() throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try gitInit(root)

        let ignoredDirectory = root.appendingPathComponent("generated", isDirectory: true)
        try FileManager.default.createDirectory(at: ignoredDirectory, withIntermediateDirectories: true)

        try "let needle = 1\n".write(
            to: root.appendingPathComponent("Tracked.swift"), atomically: true, encoding: .utf8
        )
        try "let needle = 2\n".write(
            to: ignoredDirectory.appendingPathComponent("Ignored.swift"), atomically: true, encoding: .utf8
        )
        try "generated/\n".write(
            to: root.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8
        )

        let results = try RAGLexicalFileSearcher.search(query: "needle", projectPath: root.path, topK: 5)
        let sources = Set(results.map(\.source))
        #expect(sources.contains("Tracked.swift"))
        #expect(sources.contains("generated/Ignored.swift"))
    }
}
