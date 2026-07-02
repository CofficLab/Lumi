import Foundation

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
