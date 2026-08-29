import Combine
import Foundation
import KitLLM
import ProviderLLMManager

/// SwiftUI 友好的内核 `LLMManaging` 包装器。
///
/// SwiftUI 的 `@ObservedObject` 不支持 `any LLMManaging` 类型的
/// existentials（`ObservableObject` 要求具体类型，报错
/// `type 'any LLMManaging' cannot conform to 'ObservableObject'`）。
///
/// 本包装器通过 `LLMManaging.addObserver(_:)` 订阅 `LLMManagerEvent`，
/// 把状态刷新到自身的 `@Published` 快照上，视图即可：
/// ```swift
/// @ObservedObject var box: ObservableLLMProviderManagerBox
/// box.selectedProviderID
/// box.providerInfos
/// ```
@MainActor
public final class ObservableLLMProviderManagerBox: ObservableObject {
    /// 被包装的 LLM Provider 管理器实例（写操作入口：`select(providerID:model:)` 等）。
    public let manager: any LLMManaging

    /// 当前选中的供应商 id 快照。
    @Published public private(set) var selectedProviderID: String?

    /// 当前选中的模型 id 快照。
    @Published public private(set) var selectedModel: String?

    /// 全部已注册供应商的元数据快照，按注册顺序排列。
    @Published public private(set) var providerInfos: [LLMProviderInfo] = []

    /// providerID -> 模型 id 列表快照。
    @Published public private(set) var modelIDs: [String: [String]] = [:]

    private var observer: (any LLMManagerObserverHandle)?

    public init(manager: any LLMManaging) {
        self.manager = manager
        refresh()
        // 经统一监听机制收到事件后刷新快照；弱引用避免 box 持有 manager 的
        // 回调导致循环引用。事件在 manager 状态变更后同步触发，快照始终一致。
        observer = manager.addObserver { [weak self] _ in
            self?.refresh()
        }
    }

    /// 按 id 查找供应商元数据快照；未注册时返回 `nil`。
    public func providerInfo(id: String) -> LLMProviderInfo? {
        providerInfos.first { $0.id == id }
    }

    /// 指定供应商的模型 id 列表快照；供应商未注册时返回空数组。
    public func models(for providerID: String) -> [String] {
        modelIDs[providerID] ?? []
    }

    private func refresh() {
        selectedProviderID = manager.selectedProviderID
        selectedModel = manager.selectedModel
        providerInfos = manager.allProviders().map { $0.providerInfo }
        modelIDs = Dictionary(
            uniqueKeysWithValues: manager.allProviders().map {
                ($0.providerInfo.id, manager.models(for: $0.providerInfo.id))
            }
        )
    }
}