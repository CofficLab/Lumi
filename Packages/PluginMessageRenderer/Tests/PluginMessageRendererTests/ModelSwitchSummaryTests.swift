import Testing
@testable import PluginMessageRenderer

/// 模型切换时间线主行的文案投影。
///
/// 回归 #907：模型名相同、供应商不同时，主行若只显示模型名会变成
/// `gpt-5 → gpt-5`，用户看不出这是一次真实的路由变化。
@Suite("Model switch summary")
struct ModelSwitchSummaryTests {

    @Test("同模型跨供应商时主行保留供应商（回归 #907）")
    func sameModelAcrossProvidersKeepsProviders() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "airouter",
            toModelName: "gpt-5"
        )

        #expect(summary == "openai · gpt-5 → airouter · gpt-5")
    }

    @Test("同模型跨供应商时两端标签都带供应商")
    func labelsPrefixProvidersOnlyWhenDisambiguating() {
        let labels = ModelSwitchSummary.labels(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "airouter",
            toModelName: "gpt-5"
        )

        #expect(labels.source == "openai · gpt-5")
        #expect(labels.target == "airouter · gpt-5")
    }

    @Test("模型名不同时保持紧凑文案，不追加供应商")
    func differentModelsStayCompact() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "openai",
            toModelName: "gpt-4o"
        )

        #expect(summary == "gpt-5 → gpt-4o")
    }

    @Test("同供应商同名模型仍按模型名展示")
    func sameProviderKeepsModelOnlyLabels() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "openai",
            toModelName: "gpt-5"
        )

        #expect(summary == "gpt-5 → gpt-5")
    }

    @Test("缺少任一供应商时不拼接半边供应商")
    func missingProviderDoesNotPrefix() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: nil,
            toModelName: "gpt-5"
        )

        #expect(summary == "gpt-5 → gpt-5")
    }

    @Test("首次选择模型时只显示切换后的模型")
    func firstSelectionHasNoSource() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: nil,
            fromModelName: nil,
            toProviderID: "openai",
            toModelName: "gpt-5"
        )

        #expect(summary == "切换到 gpt-5")
    }

    @Test("只有供应商 ID 时退回显示供应商")
    func providerOnlyFallsBackToIDs() {
        let summary = ModelSwitchSummary.summaryText(
            fromProviderID: "openai",
            fromModelName: nil,
            toProviderID: "airouter",
            toModelName: nil
        )

        #expect(summary == "openai → airouter")
    }
}
