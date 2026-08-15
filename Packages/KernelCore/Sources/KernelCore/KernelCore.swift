import Combine
import Foundation

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
public final class KernelCoreContainer: ObservableObject {

    // MARK: - Provider Registry

    /// Provider 注册表：以协议类型的 `ObjectIdentifier` 为 key。
    ///
    /// internal：由 `KernelCore+Provider.swift` 中的 extension 读写。
    var providers: [ObjectIdentifier: Any] = [:]

    /// Provider 变更订阅：仅当注册时选择转发 `objectWillChange` 时使用。
    ///
    /// internal：由 `KernelCore+Provider.swift` 中的 extension 读写。
    var providerSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    // MARK: - Plugin Registry

    /// 插件注册表：以插件的 `id` 为 key。
    ///
    /// internal：由 `KernelCore+Plugin.swift` 中的 extension 读写。
    var plugins: [String: any SuperPlugin] = [:]

    // MARK: - Initialization

    public init() {}
}

/// 兼容命名：用 `KernelCore` 实例化时，使用 `KernelCoreContainer`。
public typealias KernelCore = KernelCoreContainer
