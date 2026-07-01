import Foundation
import LumiCoreKit

// MARK: - LLM Availability Bootstrapping

/// LLM 可用性检测引导协议。
///
/// 插件通过实现此协议来提供 LLM 可用性检测功能。
/// 当需要初始化 LLM 可用性检测时，从插件列表中查找实现了此协议的插件并调用。
public protocol LumiLLMAvailabilityBootstrapping {
    /// 初始化可用性检测：注入适配器并异步触发全量检测。
    ///
    /// - Parameter providers: 已注册的 LLM Provider 列表
    /// - Important: 应在供应商注册完成后调用
    static func bootstrap(providers: [any LumiLLMProvider])
}

/// 辅助函数：查找并调用所有实现了 LumiLLMAvailabilityBootstrapping 的插件。
public func bootstrapLLMAvailability(plugins: [any LumiPlugin.Type], providers: [any LumiLLMProvider]) {
    for pluginType in plugins {
        if let bootstrappable = pluginType as? (any LumiLLMAvailabilityBootstrapping.Type) {
            bootstrappable.bootstrap(providers: providers)
        }
    }
}

// MARK: - Project Store Configuring

/// 项目存储配置协议。
///
/// 插件通过实现此协议来初始化项目存储功能。
/// 内核提供 projectStore 实例，插件负责持久化。
@MainActor
public protocol LumiProjectStoreConfiguring {
    /// 配置并初始化项目存储。
    ///
    /// - Parameters:
    ///   - projectPathStore: 当前项目路径存储（内核提供）
    ///   - projectStore: 项目列表存储（内核提供）
    /// - Important: 应在应用启动时调用
    static func setupStore(projectPathStore: LumiCurrentProjectPathStore, projectStore: LumiProjectStore)
    
    /// 获取已初始化的项目存储实例
    static var store: (any LumiProjectStoring)? { get }
}

/// 辅助函数：查找并调用所有实现了 LumiProjectStoreConfiguring 的插件。
@MainActor
public func bootstrapProjectStore(
    plugins: [any LumiPlugin.Type],
    projectPathStore: LumiCurrentProjectPathStore,
    projectStore: LumiProjectStore
) {
    for pluginType in plugins {
        if let config = pluginType as? (any LumiProjectStoreConfiguring.Type) {
            config.setupStore(projectPathStore: projectPathStore, projectStore: projectStore)
        }
    }
}

/// 辅助函数：获取已初始化的项目存储实例。
@MainActor
public func getProjectStore(plugins: [any LumiPlugin.Type]) -> (any LumiProjectStoring)? {
    for pluginType in plugins {
        if let config = pluginType as? (any LumiProjectStoreConfiguring.Type) {
            if let store = config.store {
                return store
            }
        }
    }
    return nil
}
