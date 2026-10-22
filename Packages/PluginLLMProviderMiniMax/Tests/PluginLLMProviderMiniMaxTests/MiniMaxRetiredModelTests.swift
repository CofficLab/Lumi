import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderMiniMax

/// 「上游已不再提供」标记（`LLMModelInfo.isRetired`）的识别与合并行为。
///
/// 背景：远程型供应商的模型池 = 静态清单 ∪ 远程列表。上游下线某模型后，
/// 远程列表不再返回它，但清单仍保留（离线兜底底座的稳定性要求）。此时该
/// 模型应被标记 `isRetired`，让 UI 能做视觉区分，而**不是**被隐藏。
@Suite("MiniMax 退役模型标记")
struct MiniMaxRetiredModelTests {

    private static let base = [
        LLMModelInfo(id: "MiniMax-M3.1-Flash", contextWindowSize: 1_000_000, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M3", contextWindowSize: 1_000_000, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.7", contextWindowSize: 204_800),
    ]

    @Test("远程缺席的清单模型被标记为已退役，但仍留在列表中")
    func marksAbsentCatalogModelsRetired() throws {
        // 远程只返回 M3 与 M3.1-Flash，M2.7 缺席
        let remote = [
            LLMModelInfo(id: "MiniMax-M3.1-Flash"),
            LLMModelInfo(id: "MiniMax-M3"),
        ]

        let merged = MiniMaxRemoteModelListLoader.merge(base: Self.base, remote: remote)

        let m27 = try #require(merged.first { $0.id == "MiniMax-M2.7" })
        #expect(m27.isRetired == true, "远程缺席的清单模型应被标记退役")
        #expect(m27.contextWindowSize == 204_800, "标记不应影响其它元数据")

        // 关键：仍在列表中，不被移除
        #expect(merged.map(\.id).contains("MiniMax-M2.7"))
    }

    @Test("远程仍提供的模型不被标记退役")
    func doesNotMarkPresentModelsRetired() throws {
        let remote = [
            LLMModelInfo(id: "MiniMax-M3.1-Flash"),
            LLMModelInfo(id: "MiniMax-M3"),
            LLMModelInfo(id: "MiniMax-M2.7"),
        ]

        let merged = MiniMaxRemoteModelListLoader.merge(base: Self.base, remote: remote)

        #expect(merged.allSatisfy { !$0.isRetired }, "远程齐全时不应有任何退役标记")
    }

    @Test("远程新增的模型不被误标退役")
    func doesNotMarkRemoteOnlyModelsRetired() {
        let remote = [
            LLMModelInfo(id: "MiniMax-M3.1-Flash"),
            LLMModelInfo(id: "MiniMax-M3"),
            LLMModelInfo(id: "MiniMax-M2.7"),
            LLMModelInfo(id: "MiniMax-M4"),  // 远程新增
        ]

        let merged = MiniMaxRemoteModelListLoader.merge(base: Self.base, remote: remote)

        let m4 = try? #require(merged.first { $0.id == "MiniMax-M4" })
        #expect(m4?.isRetired == false, "远程新增模型是上游在提供的，不应标记退役")
    }

    @Test("远程为空时不标记任何退役（否则会全量误判）")
    func doesNotMarkRetiredWhenRemoteEmpty() {
        let merged = MiniMaxRemoteModelListLoader.merge(base: Self.base, remote: [])

        #expect(merged.count == Self.base.count)
        #expect(
            merged.allSatisfy { !$0.isRetired },
            "远程无任何信息时不得标记退役，否则会把全部模型误判为已下线"
        )
    }

    @Test("标记退役不影响上下文窗口等元数据")
    func retiringPreservesMetadata() throws {
        let remote = [LLMModelInfo(id: "MiniMax-M3.1-Flash"), LLMModelInfo(id: "MiniMax-M3")]
        let merged = MiniMaxRemoteModelListLoader.merge(base: Self.base, remote: remote)

        let m27 = try #require(merged.first { $0.id == "MiniMax-M2.7" })
        let original = try #require(Self.base.first { $0.id == "MiniMax-M2.7" })
        #expect(m27.id == original.id)
        #expect(m27.displayName == original.displayName)
        #expect(m27.contextWindowSize == original.contextWindowSize)
        #expect(m27.supportsStreaming == original.supportsStreaming)
        #expect(m27.supportsVision == original.supportsVision)
        #expect(m27.supportsTools == original.supportsTools)
        #expect(m27.isRetired != original.isRetired, "只有 isRetired 应发生变化")
    }

    @Test("静态清单默认不带退役标记")
    func staticCatalogHasNoRetiredFlag() {
        // 清单是「权威待验证值」，退役与否由远程比对得出，
        // 不应在清单里硬编码——否则离线时就会误标。
        #expect(MiniMaxVendorModels.all.allSatisfy { !$0.isRetired })
    }
}