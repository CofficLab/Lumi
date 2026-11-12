import Foundation
import Testing

@testable import ProjectRAGEngine

/// Task 2.2：窗口切点优先空行 > 顶层声明起始行，小声明尽量整块保留；
/// 行号语义与 CRLF 处理不变（回归 #1114 的既有测试必须继续通过）。
@Suite struct RAGChunkerBoundaryTests {
    @Test("切点优先落在空行")
    func chunkBoundaryPrefersBlankLine() {
        var lines = (0..<4).map { "// pad \($0)" }
        lines.append("")
        lines.append(contentsOf: (0..<2).map { "// tail \($0)" })
        lines.append("func x() {")
        lines.append(contentsOf: (0..<4).map { "    step \($0)" })
        lines.append("}")
        let content = lines.joined(separator: "\n")

        let chunks = RAGChunker(maxLines: 10, overlapLines: 2).chunk(content)

        // 空行在第 5 行：首个窗口应在空行处收口，而不是拦腰切进函数体。
        #expect(chunks[0].lineRange == RAGLineRange(startLine: 1, endLine: 4))
        #expect(!chunks[0].content.contains("func x()"))
    }

    @Test("小函数整体保留在同一个块")
    func smallFunctionKeptWhole() throws {
        var lines = (0..<7).map { "// pad \($0)" }
        lines.append("func handle() {")
        lines.append(contentsOf: (0..<4).map { "    step \($0)" })
        lines.append("}")
        let content = lines.joined(separator: "\n")

        let chunks = RAGChunker(maxLines: 10, overlapLines: 2).chunk(content)

        let holder = try #require(chunks.first { $0.content.contains("func handle()") })
        #expect(holder.content.contains("step 3"))
        #expect(holder.content.contains("}"))
        #expect(!chunks[0].content.contains("func handle()"))
    }

    @Test("无空行时切点选在顶层声明起始行之前")
    func declarationStartPreferredOverMidBody() throws {
        var lines = (0..<7).map { "// pad \($0)" }
        lines.append("public struct Widget {")
        lines.append(contentsOf: (0..<4).map { "    let field\($0) = 0" })
        lines.append("}")
        let content = lines.joined(separator: "\n")

        let chunks = RAGChunker(maxLines: 10, overlapLines: 2).chunk(content)

        // 声明在第 8 行：首块应收口在第 7 行，声明整体进入下一块。
        #expect(chunks[0].lineRange == RAGLineRange(startLine: 1, endLine: 7))
        let holder = try #require(chunks.first { $0.content.contains("public struct Widget") })
        #expect(holder.content.contains("field3"))
    }

    @Test("超长声明退回字符窗口切分")
    func oversizedDeclarationFallsBackToCharWindow() {
        let longDeclaration = "func huge() { " + String(repeating: "x", count: 500) + " }"

        let chunks = RAGChunker(maxLines: 80, overlapLines: 0, maxCharsPerChunk: 100).chunk(longDeclaration)

        #expect(chunks.count > 1)
        for chunk in chunks {
            #expect(chunk.content.count <= 100)
        }
    }
}