import Foundation
import Combine
import os
import SuperLogKit

/// LumiCore Provider 状态管理器
/// 负责管理 Provider / Model 选择、可用性状态等运行时状态。
///
/// 状态变更时会通过 `NotificationCenter` 发出事件，
/// 插件可监听通知进行 UI 响应或持久化等操作，内核本身不感知插件存在。
///
/// ## 与 ProviderSettingsStore 的关系
/// - `LumiProviderState` 管理**运行时状态**（内存），供 SwiftUI / ChatService 实时读取。
/// - `ProviderSettingsStore` 负责**磁盘持久化**（plist），启动时 restore 到 state。
@MainActor
public final class LumiProviderState: ObservableObject, SuperLog {
    nonisolated public static let emoji = "🤖"
    nonisolated static let verbose = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.provider")

    // MARK: - 当前选择状态

    /// 当前选中的远程 Provider ID（nil 表示未选中或无可选远程 Provider）。
    @Published public var selectedRemoteProviderID: String? {
        didSet {
            guard selectedRemoteProviderID != oldValue else { return }
            let value = selectedRemoteProviderID
            if Self.verbose {
                Self.logger.info("\(Self.t)selectedRemoteProviderID → \(value ?? "nil")")
            }
            NotificationCenter.postSelectedRemoteProviderIDDidChange(providerID: value)
        }
    }

    /// 当前选中的本地 Provider ID（nil 表示未选中或无可选本地 Provider）。
    @Published public var selectedLocalProviderID: String? {
        didSet {
            guard selectedLocalProviderID != oldValue else { return }
            let value = selectedLocalProviderID
            if Self.verbose {
                Self.logger.info("\(Self.t)selectedLocalProviderID → \(value ?? "nil")")
            }
            NotificationCenter.postSelectedLocalProviderIDDidChange(providerID: value)
        }
    }

    /// 各 Provider 当前选中的模型 ID（providerID -> modelID）。
    @Published public private(set) var selectedModels: [String: String] = [:] {
        didSet {
            guard selectedModels != oldValue else { return }
            let value = selectedModels
            if Self.verbose {
                Self.logger.info("\(Self.t)selectedModels → \(value)")
            }
            NotificationCenter.postSelectedModelsDidChange(selectedModels: value)
        }
    }

    // MARK: - 路由模式

    /// 当前模型路由模式。
    @Published public var routingMode: LumiModelRoutingMode = .manual {
        didSet {
            guard routingMode != oldValue else { return }
            let value = routingMode
            if Self.verbose {
                Self.logger.info("\(Self.t)routingMode → \(String(describing: value))")
            }
            NotificationCenter.postRoutingModeDidChange(routingMode: value)
        }
    }

    // MARK: - 可用性状态

    /// 各 Provider 的可用性检测结果（providerID -> result）。
    @Published public private(set) var availabilityResults: [String: LumiModelAvailabilityResult] = [:] {
        didSet {
            guard availabilityResults != oldValue else { return }
            let value = availabilityResults
            if Self.verbose {
                Self.logger.info("\(Self.t)availabilityResults.count → \(value.count)")
            }
            NotificationCenter.postProviderAvailabilityDidChange(availabilityResults: value)
        }
    }

    // MARK: - Provider 运行状态

    /// 各 Provider 的运行状态（providerID -> status）。
    @Published public private(set) var providerStatuses: [String: LumiLLMProviderStatus] = [:] {
        didSet {
            guard providerStatuses != oldValue else { return }
            let value = providerStatuses
            if Self.verbose {
                Self.logger.info("\(Self.t)providerStatuses.count → \(value.count)")
            }
            NotificationCenter.postProviderStatusesDidChange(providerStatuses: value)
        }
    }

    // MARK: - 恢复状态

    /// Provider 状态是否已完成从磁盘恢复。
    ///
    /// 启动早期由持久化协调器调用 `markRestored()` 标记为 true。
    /// 在此之前，UI 层的默认选择逻辑应跳过写入 selectedProviderID，
    /// 避免首帧默认值覆盖即将恢复的持久化值。
    @Published public private(set) var isProviderStateRestored: Bool = false

    /// 标记 Provider 状态恢复完成。由持久化协调器在 restore 结束时调用一次。
    public func markRestored() {
        isProviderStateRestored = true
    }

    // MARK: - 初始化

    public init() {}

    // MARK: - 选择状态读写

    /// 读取指定 Provider 的当前选中模型 ID，未设置时返回 nil。
    public func selectedModel(for providerID: String) -> String? {
        selectedModels[providerID]
    }

    /// 设置指定 Provider 的选中模型 ID。
    public func setSelectedModel(_ modelID: String?, for providerID: String) {
        var models = selectedModels
        if let modelID {
            models[providerID] = modelID
        } else {
            models.removeValue(forKey: providerID)
        }
        selectedModels = models
    }

    /// 批量更新选中模型映射（恢复时使用，触发单次变更通知）。
    public func restoreSelectedModels(_ models: [String: String]) {
        selectedModels = models
    }

    // MARK: - 可用性状态读写

    /// 读取指定 Provider 的可用性结果，未检测过返回 nil。
    public func availabilityResult(for providerID: String) -> LumiModelAvailabilityResult? {
        availabilityResults[providerID]
    }

    /// 设置指定 Provider 的可用性结果。
    public func setAvailabilityResult(_ result: LumiModelAvailabilityResult, for providerID: String) {
        availabilityResults[providerID] = result
    }

    /// 批量回填可用性结果（恢复时使用，触发单次变更通知）。
    public func restoreAvailabilityResults(_ results: [String: LumiModelAvailabilityResult]) {
        availabilityResults = results
    }

    // MARK: - Provider 运行状态读写

    /// 读取指定 Provider 的运行状态，未检测过返回 nil。
    public func providerStatus(for providerID: String) -> LumiLLMProviderStatus? {
        providerStatuses[providerID]
    }

    /// 设置指定 Provider 的运行状态。
    public func setProviderStatus(_ status: LumiLLMProviderStatus?, for providerID: String) {
        if let status {
            providerStatuses[providerID] = status
        } else {
            providerStatuses.removeValue(forKey: providerID)
        }
    }

    /// 批量回填 Provider 状态（恢复时使用，触发单次变更通知）。
    public func restoreProviderStatuses(_ statuses: [String: LumiLLMProviderStatus]) {
        providerStatuses = statuses
    }
}

// MARK: - NotificationCenter 扩展

public extension NotificationCenter {
    private static let selectedRemoteProviderIDDidChange = Notification.Name("LumiProviderState.SelectedRemoteProviderIDDidChange")
    private static let selectedLocalProviderIDDidChange = Notification.Name("LumiProviderState.SelectedLocalProviderIDDidChange")
    private static let selectedModelsDidChange = Notification.Name("LumiProviderState.SelectedModelsDidChange")
    private static let routingModeDidChange = Notification.Name("LumiProviderState.RoutingModeDidChange")
    private static let providerAvailabilityDidChange = Notification.Name("LumiProviderState.AvailabilityDidChange")
    private static let providerStatusesDidChange = Notification.Name("LumiProviderState.StatusesDidChange")

    static func postSelectedRemoteProviderIDDidChange(providerID: String?) {
        let userInfo: [String: Any?] = ["providerID": providerID]
        NotificationCenter.default.post(name: selectedRemoteProviderIDDidChange, object: nil, userInfo: userInfo)
    }

    static func postSelectedLocalProviderIDDidChange(providerID: String?) {
        let userInfo: [String: Any?] = ["providerID": providerID]
        NotificationCenter.default.post(name: selectedLocalProviderIDDidChange, object: nil, userInfo: userInfo)
    }

    static func postSelectedModelsDidChange(selectedModels: [String: String]) {
        NotificationCenter.default.post(name: selectedModelsDidChange, object: nil, userInfo: ["selectedModels": selectedModels])
    }

    static func postRoutingModeDidChange(routingMode: LumiModelRoutingMode) {
        NotificationCenter.default.post(name: routingModeDidChange, object: nil, userInfo: ["routingMode": routingMode])
    }

    static func postProviderAvailabilityDidChange(availabilityResults: [String: LumiModelAvailabilityResult]) {
        NotificationCenter.default.post(name: providerAvailabilityDidChange, object: nil, userInfo: ["availabilityResults": availabilityResults])
    }

    static func postProviderStatusesDidChange(providerStatuses: [String: LumiLLMProviderStatus]) {
        NotificationCenter.default.post(name: providerStatusesDidChange, object: nil, userInfo: ["providerStatuses": providerStatuses])
    }
}
