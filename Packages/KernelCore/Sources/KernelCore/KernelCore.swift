import Foundation
import os

enum KernelPluginLifecyclePhase {
    case boot
}

public enum KernelLifecycleState: String, Sendable {
    case stopped
    case starting
    case running
    case stopping
    case failed
}

/// KernelCore 轻量级内核核心
///
/// 架构原则：KernelCore 只提供「注册 Provider 与访问 Provider」的通用机制，
/// **不定义、不包含任何具体 Provider**（如 StorageProviding、ProjectProviding 等）。
/// 具体 Provider 协议由上层（如 KernelLumi）或具体 App 声明，实现由插件注入。
///
/// Provider 注册/解析相关函数集中在 `KernelCore+Provider.swift` 扩展中。
///
/// Only holds protocol types, does not depend on concrete implementations.
/// All concrete implementations are injected via plugins.
@MainActor
public final class KernelCoreContainer {

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "kernel.provider"
    )

    // MARK: - Provider Registry

    /// Provider 注册表：以协议类型的 `ObjectIdentifier` 为 key。
    ///
    /// internal：由 `KernelCore+Provider.swift` 中的 extension 读写。
    var providers: [ObjectIdentifier: Any] = [:]

    /// Provider 所属插件。不存在记录时表示由宿主注册。
    var providerOwners: [ObjectIdentifier: String] = [:]

    // MARK: - Plugin Registry

    /// 插件注册表：以插件的 `id` 为 key。
    ///
    /// internal：由 `KernelCore+Plugin.swift` 中的 extension 读写。
    var plugins: [String: any SuperPlugin] = [:]

    var pluginStartOrder: [String] = []
    var activePluginID: String?
    var activePluginLifecyclePhase: KernelPluginLifecyclePhase?
    var pluginEnabledStates: [String: Bool] = [:]

    /// 插件启用状态的持久化存储；未注入时仅维护运行时状态。
    public var stateStore: (any PluginStatePersisting)?

    /// 新插件 ID 到旧插件 ID 的兼容映射。
    /// 读取时先查新 ID，再回退旧 ID；写入时同步更新两者。
    public var legacyPluginIDAliases: [String: String] = [:]

    /// 插件写入共享 Provider/Host 的贡献，由 Kernel 统一持有和撤回。
    var contributionTokens: [String: [PluginContributionToken]] = [:]

    /// 生命周期状态是内核内部控制状态，不是 UI 发布源。
    /// 需要感知插件生命周期的消费者应观察对应的 Provider（例如
    /// `PluginManaging.addPluginObserver`），而不是观察 Kernel。
    public private(set) var lifecycleState: KernelLifecycleState = .stopped

    // MARK: - Initialization

    public init() {}

    func setLifecycleState(_ state: KernelLifecycleState) {
        lifecycleState = state
    }
}

/// 兼容命名：用 `KernelCore` 实例化时，使用 `KernelCoreContainer`。
public typealias KernelCore = KernelCoreContainer
