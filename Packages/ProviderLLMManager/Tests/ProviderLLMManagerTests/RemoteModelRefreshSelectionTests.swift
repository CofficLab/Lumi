import Foundation
import KitLLM
import Testing
@testable import ProviderLLMManager

/// 把选中态持久化重定向到**隔离的偏好域**，并在测试结束后还原。
///
/// - Important: `LLMManagerUserDefaults.current` 是进程级静态状态，
///   测试必须在自己的用例内接管并还原，避免污染开发者本机偏好。
private final class RemoteRefreshDefaultsSnapshot: SuiteTrait, @unchecked Sendable {
    private let lock = NSLock()
    private let suiteName: String
    private let isolated: UserDefaults

    init() {
        self.suiteName = "com.coffic.lumi.test.llm-manager.refresh.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("无法创建隔离的 UserDefaults（suite: \(suiteName)）")
        }
        self.isolated = defaults
    }

    func setUp() async throws {
        let defaults = isolated
        defaults.removePersistentDomain(forName: suiteName)
        LLMManagerUserDefaults.current = defaults
    }

    deinit {
        let defaults = isolated
        defaults.removePersistentDomain(forName: suiteName)
        LLMManagerUserDefaults.current = .standard
    }
}

/// 可远程增删模型的供应商替身：模拟远程快照刷新后模型池变化。
@MainActor
private final class MutableRemoteProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo
    /// 当前远程快照中的模型；刷新可整体替换。
    var remoteModels: [LLMModelInfo]

    init(id: String, baseModels: [String], defaultModel: String, remoteModels: [String]) {
        self.providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: defaultModel,
            models: baseModels.map { LLMModelInfo(id: $0) }
        )
        self.remoteModels = remoteModels.map { LLMModelInfo(id: $0) }
    }

    var providerID: String { providerInfo.id }

    var usesRemoteModelList: Bool { true }

    var availableModels: [LLMModelInfo] {
        var seen = Set(providerInfo.models.map(\.id))
        var merged = providerInfo.models
        for model in remoteModels where !seen.contains(model.id) {
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

/// 远程模型刷新后必须重校验持久化的选中态。
///
/// ## 为什么要有这条测试
///
/// 远程刷新成功后模型池会整体替换：上次快照新增、这次被移除的模型会从
/// 动态池消失。若管理器不重校验 `selectedModelID`，就会留下一个**已失效**
/// 的持久化选中：
/// - 模型选择按钮显示 "Select Provider"（路由解析失败）；
/// - 发送链路却静默回退到该供应商的默认模型。
///
/// 结果是 UI、持久化选择与真实请求三者不一致，用户既没看到也没确认过这次
/// 切换。正确行为是：刷新后同步重校验选择并广播新的有效选择。
@MainActor
@Suite("远程刷新后的选中态重校验", .serialized, RemoteRefreshDefaultsSnapshot())
struct RemoteModelRefreshSelectionTests {

    @Test("刷新移除当前选中的远程模型后重校验为默认模型并广播选择变化")
    func selectionRevalidatedAfterRemoteRefresh() throws {
        let manager = DefaultLLMManager()
        let provider = MutableRemoteProvider(
            id: "goatplan",
            baseModels: ["base-a"],
            defaultModel: "base-a",
            remoteModels: ["remote-r"]
        )
        try manager.register(provider)
        manager.select(providerID: "goatplan", model: "remote-r", reason: .userSelected)
        #expect(manager.selectedModelID?.modelID == "remote-r")

        var events: [LLMManagerEvent] = []
        let handle = manager.addObserver { events.append($0) }
        defer { handle.cancel() }

        // 新的远程快照不再包含 remote-r。
        provider.remoteModels = []
        manager.notifyModelsRefreshed(providerID: "goatplan")

        #expect(
            manager.selectedModelID?.modelID == "base-a",
            "失效的远程模型仍留在选中态：\(String(describing: manager.selectedModelID))"
        )
        #expect(manager.selectedModelID?.providerID == "goatplan")

        let selectionChanges = events.compactMap { event -> (String?, String?, ModelSelectionReason)? in
            guard case let .selectionChanged(providerID, model, reason) = event else { return nil }
            return (providerID, model, reason)
        }
        #expect(selectionChanges.count == 1, "刷新后未广播选择变化：\(events)")
        #expect(selectionChanges.first?.0 == "goatplan")
        #expect(selectionChanges.first?.1 == "base-a")
        #expect(selectionChanges.first?.2 == .remoteModelsRefreshed)
    }

    @Test("刷新后选中模型仍然有效时不广播选择变化")
    func noSelectionChangeWhenSelectionStillValid() throws {
        let manager = DefaultLLMManager()
        let provider = MutableRemoteProvider(
            id: "goatplan-keep",
            baseModels: ["base-a"],
            defaultModel: "base-a",
            remoteModels: ["remote-r"]
        )
        try manager.register(provider)
        manager.select(providerID: "goatplan-keep", model: "remote-r", reason: .userSelected)

        var events: [LLMManagerEvent] = []
        let handle = manager.addObserver { events.append($0) }
        defer { handle.cancel() }

        // 新的远程快照仍包含 remote-r（只新增了别的模型），选中保持有效。
        provider.remoteModels = [LLMModelInfo(id: "remote-r"), LLMModelInfo(id: "remote-new")]
        manager.notifyModelsRefreshed(providerID: "goatplan-keep")

        #expect(manager.selectedModelID?.modelID == "remote-r")
        let selectionChanges = events.compactMap { event -> ModelSelectionReason? in
            guard case let .selectionChanged(_, _, reason) = event else { return nil }
            return reason
        }
        #expect(selectionChanges.isEmpty, "选中未变化时不应广播选择变化：\(events)")
    }

    @Test("刷新移除选中的远程模型后，请求不再静默回退到失效模型")
    func requestUsesRevalidatedSelection() async throws {
        let manager = DefaultLLMManager()
        let provider = MutableRemoteProvider(
            id: "goatplan-request",
            baseModels: ["base-a"],
            defaultModel: "base-a",
            remoteModels: ["remote-r"]
        )
        try manager.register(provider)
        manager.select(providerID: "goatplan-request", model: "remote-r", reason: .userSelected)

        provider.remoteModels = []
        manager.notifyModelsRefreshed(providerID: "goatplan-request")

        let route = manager.selectedModelID.flatMap { manager.modelRoute(for: $0) }
        #expect(route != nil, "刷新后选中态无法解析出路由")
        #expect(route?.modelName == "base-a")
    }
}
