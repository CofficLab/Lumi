import Foundation
import Testing
@testable import ProjectRAGEngine

/// grep 工具的内容搜索层：忠实执行用户正则，不依赖索引，不受 .gitignore 影响。
@Suite struct RAGGrepSearcherTests {

    private func makeProject() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-grep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
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

    @Test func findsLiteralAndRegexMatches() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("func handleRequest() {}\nfunc HandleRequest() {}\n", to: root.appendingPathComponent("Core.swift"))

        let literal = try await RAGGrepSearcher.search(pattern: "handleRequest", projectPath: root.path)
        #expect(literal.totalMatchCount == 1)
        #expect(literal.matches.first?.lineNumber == 1)

        let regex = try await RAGGrepSearcher.search(pattern: "[Hh]andleRequest", projectPath: root.path)
        #expect(regex.totalMatchCount == 2)
        #expect(regex.matches.allSatisfy { !$0.isContext })
    }

    @Test func respectsNoIgnore() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try gitInit(root)
        try write("let needle = 1\n", to: root.appendingPathComponent("Tracked.swift"))
        try write("let needle = 2\n", to: root.appendingPathComponent("generated/Ignored.swift"))
        try write("generated/\n", to: root.appendingPathComponent(".gitignore"))

        let outcome = try await RAGGrepSearcher.search(pattern: "needle", projectPath: root.path)
        let names = Set(outcome.matches.map { ($0.filePath as NSString).lastPathComponent })
        #expect(names.contains("Tracked.swift"))
        #expect(names.contains("Ignored.swift"))
    }

    @Test func globFilterWorks() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("needle\n", to: root.appendingPathComponent("a.swift"))
        try write("needle\n", to: root.appendingPathComponent("notes.md"))

        let outcome = try await RAGGrepSearcher.search(pattern: "needle", projectPath: root.path, glob: "*.swift")
        #expect(outcome.totalMatchCount == 1)
        #expect(outcome.matches.first?.filePath.hasSuffix("a.swift") == true)
    }

    @Test func caseInsensitiveFlagWorks() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Needle\n", to: root.appendingPathComponent("A.swift"))

        let sensitive = try await RAGGrepSearcher.search(pattern: "needle", projectPath: root.path)
        #expect(sensitive.totalMatchCount == 0)

        let insensitive = try await RAGGrepSearcher.search(
            pattern: "needle", projectPath: root.path, caseInsensitive: true
        )
        #expect(insensitive.totalMatchCount == 1)
    }

    @Test func invalidRegexThrows() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("content\n", to: root.appendingPathComponent("A.swift"))

        await #expect(throws: RAGGrepError.self) {
            _ = try await RAGGrepSearcher.search(pattern: "[", projectPath: root.path)
        }
    }

    @Test func missingRipgrepThrows() async {
        await #expect(throws: RAGGrepError.self) {
            _ = try await RAGGrepSearcher.search(
                pattern: "x",
                projectPath: FileManager.default.temporaryDirectory.path,
                ripgrepURL: URL(fileURLWithPath: "/nonexistent/rg-\(UUID().uuidString)")
            )
        }
    }

    @Test func maxResultsCapsMatchesButCountsAll() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        let lines = (1...10).map { "line \($0) needle" }.joined(separator: "\n")
        try write(lines + "\n", to: root.appendingPathComponent("Many.swift"))

        let outcome = try await RAGGrepSearcher.search(pattern: "needle", projectPath: root.path, maxResults: 3)
        #expect(outcome.matches.filter { !$0.isContext }.count == 3)
        #expect(outcome.totalMatchCount == 10)
    }

    @Test func contextLinesIncluded() async throws {
        let root = try makeProject()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("alpha\nneedle\nomega\n", to: root.appendingPathComponent("Ctx.swift"))

        let outcome = try await RAGGrepSearcher.search(pattern: "needle", projectPath: root.path, contextLines: 1)
        #expect(outcome.matches.count == 3)
        #expect(outcome.matches.filter(\.isContext).count == 2)
        #expect(outcome.totalMatchCount == 1)
    }

    @Test func outputBudgetTruncatesWithMarker() {
        let matches = (0..<400).map { index in
            RAGGrepMatch(
                filePath: "/p/File.swift",
                lineNumber: index + 1,
                text: String(repeating: "x", count: 120),
                isContext: false
            )
        }
        let outcome = RAGGrepOutcome(matches: matches, totalMatchCount: 400)
        let output = RAGGrepSearcher.formatOutput(outcome, projectPath: "/p")

        #expect(output.utf8.count <= RAGGrepSearcher.maxOutputBytes)
        let shown = output.split(separator: "\n").filter { $0.hasPrefix("File.swift:") }.count
        #expect(shown > 0)
        #expect(shown < 400)
        #expect(output.contains("[truncated: \(400 - shown) more matches"))
    }

    @Test func formatOutputUsesRelativePathsAndContextSeparator() {
        let outcome = RAGGrepOutcome(
            matches: [
                RAGGrepMatch(filePath: "/p/src/A.swift", lineNumber: 1, text: "alpha", isContext: true),
                RAGGrepMatch(filePath: "/p/src/A.swift", lineNumber: 2, text: "needle", isContext: false),
            ],
            totalMatchCount: 1
        )
        let output = RAGGrepSearcher.formatOutput(outcome, projectPath: "/p")
        #expect(output.contains("src/A.swift-1-alpha"))
        #expect(output.contains("src/A.swift:2:needle"))
        #expect(!output.contains("[truncated:"))
    }
}