import Foundation
@testable import PluginProjectRAG
import ProjectRAGEngine
import ProviderProjectRAG
import Testing

/// 跨路排序必须用 RRF：原始分量纲不同，跨源共识优先于单路高分。
@Suite("CodeNavigationFusion", .serialized)
@MainActor
struct CodeNavigationFusionTests {

    private func input(
        _ source: String,
        _ start: Int?,
        _ end: Int?,
        content: String = "",
        score: Float
    ) -> RAGFusionInput {
        RAGFusionInput(source: source, startLine: start, endLine: end, content: content, score: score)
    }

    @Test("rrf prefers cross-source consensus")
    func rrfPrefersCrossSourceConsensus() {
        // X 在词法/路径都排第 1、语义第 5；Y 仅语义第 1 但原始分最高。
        // 旧的原始分排序会选 Y，RRF 必须选 X。
        let semantic = [
            input("Y.swift", 1, 5, content: "y", score: 0.99),
            input("S2.swift", 1, 5, content: "s2", score: 0.9),
            input("S3.swift", 1, 5, content: "s3", score: 0.8),
            input("S4.swift", 1, 5, content: "s4", score: 0.7),
            input("X.swift", 1, 5, content: "x", score: 0.3),
        ]
        let lexical = [input("X.swift", 1, 5, content: "x", score: 0.2)]
        let path = [input("X.swift", 1, 5, content: "x", score: 0.1)]

        let fused = RAGRankFusion.fuse([semantic, lexical, path], limit: 5)
        let first = fused[0]
        let lists = [semantic, lexical, path]
        #expect(lists[first.listIndex][first.itemIndex].source == "X.swift")
        #expect(first.bestOriginalScore == 0.3)
        #expect(first.fusedScore > fused[1].fusedScore)
    }

    @Test("overlapping line ranges deduplicated")
    func overlappingLineRangesDeduplicated() {
        let semantic = [input("A.swift", 15, 25, content: "c2", score: 0.9)]
        let lexical = [input("A.swift", 10, 20, content: "c1", score: 0.8)]

        let fused = RAGRankFusion.fuse([semantic, lexical], limit: 10)
        #expect(fused.count == 1)
        #expect(fused[0].bestOriginalScore == 0.9)
        #expect(fused[0].fusedScore > 1.0 / 61.0)
    }

    @Test("display score keeps best original")
    func displayScoreKeepsBestOriginal() {
        let a = [input("A.swift", 1, 3, content: "same", score: 0.4)]
        let b = [input("A.swift", 1, 3, content: "same", score: 0.7)]

        let fused = RAGRankFusion.fuse([a, b], limit: 5)
        #expect(fused.count == 1)
        #expect(fused[0].bestOriginalScore == 0.7)
    }

    @Test("identical content deduplicated across sources")
    func identicalContentDeduplicatedAcrossSources() {
        let a = [input("A.swift", nil, nil, content: "same", score: 0.5)]
        let b = [input("B.swift", nil, nil, content: "same", score: 0.6)]

        #expect(RAGRankFusion.fuse([a, b], limit: 5).count == 1)
    }

    @Test("coordinator orders cross-source consensus first")
    func coordinatorOrdersCrossSourceConsensusFirst() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rag-fusion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "let liveNeedle = 42\n".write(
            to: root.appendingPathComponent("X.swift"), atomically: true, encoding: .utf8
        )

        // Y 原始分 0.99 仅语义一路；X 语义第 2 + 词法第 1，RRF 应排前。
        let semanticY = ProjectRAGSearchResult(
            content: "y", source: "Sources/Y.swift", score: 0.99,
            matchKind: .semantic, lineRange: ProjectRAGLineRange(startLine: 1, endLine: 5)
        )
        let semanticX = ProjectRAGSearchResult(
            content: "x", source: "X.swift", score: 0.3,
            matchKind: .semantic, lineRange: ProjectRAGLineRange(startLine: 1, endLine: 3)
        )
        let provider = IndexingStubProvider(
            indexing: false, hasIndex: true, semanticResults: [semanticY, semanticX]
        )

        let response = try await CodeNavigationCoordinator(provider: provider).search(
            query: "liveNeedle", projectPath: root.path, topK: 5
        )

        let first = try #require(response.results.first)
        #expect(first.source == "X.swift")
        // 展示分保留该证据的最佳原始分（词法 0.85 > 语义 0.3）。
        #expect(abs(first.score - 0.85) < 0.001)
    }
}