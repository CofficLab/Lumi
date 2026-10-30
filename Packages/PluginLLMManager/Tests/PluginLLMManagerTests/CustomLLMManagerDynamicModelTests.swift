import Foundation
import KitLLM
import ProviderLLMManager
import Testing
@testable import PluginLLMManager

/// `CustomLLMManager` 必须读取**动态模型池**（`provider.availableModels`），
/// 而非静态清单 `providerInfo.models`。
///
/// ## 为什么要有这条测试
///
/// 生产环境注册的是 `CustomLLMManager`（`PluginLLMManager` 插件在 `onBoot`
/// 替换掉 `DefaultLLMManager`），而远程型供应商（MiniMax / CommandCode）
/// 的模型列表只在 `availableModels` 里：静态清单是注册时写死的，远程刷新
/// 新增的模型只存在于动态池。
///
/// 曾因 `CustomLLMManager` 读静态清单导致：
/// - UI 列表（走 `dynamicModels`）显示远程新模型；
/// - 但点选时 `modelID` 校验走静态清单 → 解析失败 → **选不中**；
/// - 发送链路 `routedModel` 同样按静态清单校验 → 回退到默认模型。
///
/// 症状就是「刷新后看得到、点不动」，且不报错。
@MainActor
@Suite("CustomLLMManager 动态模型池", .serialized)
struct CustomLLMManagerDynamicModelTests {

    @Test("models(for:) 读取动态模型池，含远程新增模型")
    func modelsReadsDynamicPool() throws {
        let manager = CustomLLMManager()
        let provider = DynamicEchoProvider(
            id: "minimax-tokenplan",
            staticModels: ["MiniMax-M2.7", "MiniMax-M2.5"],
            remoteModels: ["MiniMax-M2.1", "MiniMax-M2"]
        )
        try manager.register(provider)

        #expect(provider.availableModels.count == 4)
        #expect(
            manager.models(for: "minimax-tokenplan").contains("MiniMax-M2.1"),
            "远程新增模型丢失：\(manager.models(for: "minimax-tokenplan"))"
        )
    }

    @Test("远程新增模型可解析 modelID 并路由")
    func remoteModelSelectableAndRoutable() throws {
        let manager = CustomLLMManager()
        let provider = DynamicEchoProvider(
            id: "minimax-tokenplan",
            staticModels: ["MiniMax-M2.7"],
            remoteModels: ["MiniMax-M2.1"]
        )
        try manager.register(provider)

        let modelID = try #require(
            manager.modelID(providerID: "minimax-tokenplan", model: "MiniMax-M2.1"),
            "远程新增模型无法解析出 modelID"
        )
        let route = try #require(manager.modelRoute(for: modelID))
        #expect(route.modelName == "MiniMax-M2.1")
    }

    @Test("请求自带远程新增模型时不被回退到默认模型")
    func requestedRemoteModelIsNotDowngraded() async throws {
        let manager = CustomLLMManager()
        let provider = DynamicEchoProvider(
            id: "minimax-tokenplan",
            staticModels: ["MiniMax-M2.7"],
            remoteModels: ["MiniMax-M2.1"]
        )
        try manager.register(provider)

        let response = try await manager.complete(LLMRequest(
            conversationID: UUID(),
            messages: [LLMMessage(role: .user, content: "ping")],
            model: "MiniMax-M2.1"
        ))

        #expect(
            provider.receivedModels == ["MiniMax-M2.1"],
            "远程新增模型被回退：\(provider.receivedModels)"
        )
        #expect(response.content == "minimax-tokenplan:MiniMax-M2.1")
    }
}

/// 静态清单 + 远程可注入的供应商替身。
@MainActor
private final class DynamicEchoProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo
    var providerID: String { providerInfo.id }

    private(set) var receivedModels: [String] = []

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
        let model = request.model ?? ""
        receivedModels.append(model)
        return LLMResponse(content: "\(providerInfo.id):\(model)", model: request.model)
    }
}
