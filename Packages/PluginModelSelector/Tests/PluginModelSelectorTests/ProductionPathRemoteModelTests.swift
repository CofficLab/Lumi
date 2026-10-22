import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginModelSelector

/// 模型选择器「列表可见 → 可点选 → 写入选中态 → 可路由」的端到端一致性。
///
/// ## 为什么要有这条测试
///
/// 插件内两条路径读的模型池必须一致：
/// - UI 列表走 `LLMProviderManagerBox.refresh()` → `manager.dynamicModels(of:)`；
/// - 点选走 `box.modelID(...)` → `manager.modelID(...)`。
///
/// 若管理器按**静态清单**校验模型，点选远程新增模型会静默失败：
/// 列表看得到、点不动、无报错。
///
/// - Important: 本包依赖 `ProviderLLMManager`，生产环境实际注册的是
///   `PluginLLMManager` 里的 `CustomLLMManager`。管理器侧的一致性由
///   `PluginLLMManager` 包的 `CustomLLMManagerDynamicModelTests` 覆盖。
@MainActor
struct ProductionPathRemoteModelTests {

    @Test("远程新增模型在列表可见、可点选、写入全局选中态")
    func productionPathSelection() throws {
        let manager = DefaultLLMManager()
        let provider = ProdPathProvider(
            id: "minimax-tokenplan",
            staticModels: ["MiniMax-M2.7"],
            remoteModels: ["MiniMax-M2.1"]
        )
        try manager.register(provider)

        let box = LLMProviderManagerBox(manager: manager)
        let viewModel = ModelSelectorViewModel(
            box: box,
            usageStore: ProviderUsageStore(directory: nil),
            toastCapability: ModelSelectorToastCapabilityAdapter(toast: nil)
        )
        viewModel.selectedProviderID = provider.providerID

        // 1) UI 列表：走 dynamicModels，能看到远程新模型
        #expect(
            viewModel.visibleModels(for: provider.providerID).contains("MiniMax-M2.1"),
            "UI 列表应显示远程新增模型"
        )

        // 2) 点选：走 box.modelID → manager.modelID
        #expect(
            box.modelID(providerID: provider.providerID, model: "MiniMax-M2.1") != nil,
            "点选远程新增模型时 modelID 解析失败 → 选不中"
        )

        // 3) 选中写入全局并可路由（发送链路依赖）
        viewModel.select(providerID: provider.providerID, model: "MiniMax-M2.1")

        #expect(manager.selectedModel == "MiniMax-M2.1", "远程新增模型选不中")
        #expect(viewModel.isSelected(providerID: provider.providerID, model: "MiniMax-M2.1"))

        let route = try #require(manager.modelRoute(for: manager.selectedModelID!))
        #expect(route.modelName == "MiniMax-M2.1")
    }
}

/// 生产路径替身：静态清单 + 远程可注入。
@MainActor
private final class ProdPathProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo
    var providerID: String { providerInfo.id }

    private var remote: [LLMModelInfo] = []

    init(id: String, staticModels: [String], remoteModels: [String]) {
        providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: staticModels.first ?? "",
            models: staticModels.map { LLMModelInfo(id: $0) }
        )
        remote = remoteModels.map { LLMModelInfo(id: $0) }
    }

    var usesRemoteModelList: Bool { true }

    var availableModels: [LLMModelInfo] {
        var seen = Set(providerInfo.models.map(\.id))
        var merged = providerInfo.models
        for model in remote where !seen.contains(model.id) {
            merged.append(model)
            seen.insert(model.id)
        }
        return merged
    }

    func refreshModels() async throws {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}
