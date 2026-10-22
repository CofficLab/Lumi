import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderMiniMax

/// `MiniMaxModelFamily` 家族推断规则。
///
/// 规则来源：2026-10 实测国内站 `/v1/models` + 官方文档
/// （`platform.minimaxi.com/docs/api-reference/text-openai-api`）。
/// 上下文窗口另经服务端 `max_tokens` 上限报错交叉验证：
/// M3 系列报 `> 524288`（1M 上下文的 52.4%），
/// M2 系列报 `> 196608`（204,800 的 96%）。
@Suite("MiniMax 模型家族推断")
struct MiniMaxModelFamilyTests {

    // MARK: - 家族识别

    @Test("M3 系列识别为 m3 家族", arguments: [
        "MiniMax-M3",
        "MiniMax-M3.1-Flash",
        "MiniMax-M3-highspeed",
    ])
    func recognizesM3Family(_ modelID: String) {
        #expect(MiniMaxModelFamily.family(for: modelID) == .m3)
    }

    @Test("M2 系列识别为 m2 家族", arguments: [
        "MiniMax-M2",
        "MiniMax-M2.1",
        "MiniMax-M2.1-highspeed",
        "MiniMax-M2.5",
        "MiniMax-M2.5-highspeed",
        "MiniMax-M2.7",
        "MiniMax-M2.7-highspeed",
    ])
    func recognizesM2Family(_ modelID: String) {
        #expect(MiniMaxModelFamily.family(for: modelID) == .m2)
    }

    @Test("未知系列不猜测，返回 unknown", arguments: [
        "MiniMax-Speech-2.8-HD",
        "MiniMax-H3",
        "MiniMax-Music-3.0",
        "MiniMax-M4",
        "gpt-4o",
        "",
    ])
    func unknownFamilyIsNotGuessed(_ modelID: String) {
        #expect(MiniMaxModelFamily.family(for: modelID) == .unknown)
    }

    // MARK: - 元数据取值

    @Test("M3 家族为 1M 上下文且支持视觉")
    func m3FamilyMetadata() {
        let family = MiniMaxModelFamily.m3
        #expect(family.contextWindowSize == 1_000_000)
        #expect(family.supportsVision == true)
    }

    @Test("M2 家族为 204,800 上下文且不支持视觉")
    func m2FamilyMetadata() {
        let family = MiniMaxModelFamily.m2
        #expect(family.contextWindowSize == 204_800)
        // 官方文档：M2.7 / M2.5 / M2.1 / M2 仅支持文本与工具调用
        #expect(family.supportsVision == false)
    }

    @Test("未知家族不提供上下文窗口")
    func unknownFamilyHasNoContextWindow() {
        #expect(MiniMaxModelFamily.unknown.contextWindowSize == nil)
        #expect(MiniMaxModelFamily.unknown.supportsVision == false)
    }

    // MARK: - enriched

    @Test("enriched 按家族补全上下文窗口与视觉能力")
    func enrichedFillsMetadataByFamily() {
        let m3 = MiniMaxModelFamily.enriched("MiniMax-M3.1-Flash")
        #expect(m3.id == "MiniMax-M3.1-Flash")
        #expect(m3.contextWindowSize == 1_000_000)
        #expect(m3.supportsVision == true)

        let m2 = MiniMaxModelFamily.enriched("MiniMax-M2.1-highspeed")
        #expect(m2.id == "MiniMax-M2.1-highspeed")
        #expect(m2.contextWindowSize == 204_800)
        #expect(m2.supportsVision == false)
    }

    @Test("enriched 对未知家族保持上下文窗口为 nil，不落 32K 兜底")
    func enrichedKeepsNilForUnknownFamily() {
        let unknown = MiniMaxModelFamily.enriched("MiniMax-Speech-2.8-HD")
        #expect(unknown.contextWindowSize == nil)
    }

    // MARK: - 合并行为

    @Test("合并后远程新增模型带上家族推断的上下文窗口")
    func mergedRemoteModelCarriesContextWindow() throws {
        let base = MiniMaxVendorModels.all
        // 模拟上游新增一个尚未进清单的 M2 系列模型
        let remote = [
            LLMModelInfo(id: "MiniMax-M2.9"),
            LLMModelInfo(id: "MiniMax-M3.5"),
        ]

        let merged = MiniMaxRemoteModelListLoader.merge(base: base, remote: remote)

        #expect(merged.count == base.count + 2)

        let m29 = try #require(merged.first { $0.id == "MiniMax-M2.9" })
        #expect(m29.contextWindowSize == 204_800)
        #expect(m29.supportsVision == false)

        let m35 = try #require(merged.first { $0.id == "MiniMax-M3.5" })
        #expect(m35.contextWindowSize == 1_000_000)
        #expect(m35.supportsVision == true)
    }

    @Test("合并时静态清单优先，远程不覆盖同 id 的元数据")
    func mergePrefersStaticMetadata() throws {
        let base = MiniMaxVendorModels.all
        // 远程同 id 但元数据不同（模拟家族规则变更后误覆盖）
        let remote = [
            LLMModelInfo(id: "MiniMax-M2.7", contextWindowSize: 999, supportsVision: true),
        ]

        let merged = MiniMaxRemoteModelListLoader.merge(base: base, remote: remote)

        #expect(merged.count == base.count, "同 id 不应产生重复条目")
        let m27 = try #require(merged.first { $0.id == "MiniMax-M2.7" })
        #expect(m27.contextWindowSize == 204_800, "应保留静态清单的上下文窗口")
        #expect(m27.supportsVision == false, "应保留静态清单的视觉能力")
    }

    // MARK: - 静态清单一致性

    @Test("静态清单每个模型的元数据与家族规则一致")
    func staticCatalogMatchesFamilyRules() {
        for model in MiniMaxVendorModels.all {
            let family = MiniMaxModelFamily.family(for: model.id)
            #expect(family != .unknown, "\(model.id) 应属于已知家族")
            #expect(model.contextWindowSize == family.contextWindowSize,
                    "\(model.id) 上下文窗口与家族规则不一致")
            #expect(model.supportsVision == family.supportsVision,
                    "\(model.id) 视觉能力与家族规则不一致")
        }
    }

    @Test("静态清单 id 与上游实测返回逐字一致")
    func staticCatalogIDsMatchUpstream() {
        // 上游 `GET /v1/models` 实测返回的 9 个 id
        #expect(MiniMaxVendorModels.all.map(\.id) == [
            "MiniMax-M3.1-Flash",
            "MiniMax-M3",
            "MiniMax-M2.7",
            "MiniMax-M2.7-highspeed",
            "MiniMax-M2.5",
            "MiniMax-M2.5-highspeed",
            "MiniMax-M2.1",
            "MiniMax-M2.1-highspeed",
            "MiniMax-M2",
        ])
    }
}
