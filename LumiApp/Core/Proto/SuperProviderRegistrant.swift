import Foundation

/// 供应商注册协议
///
/// 允许供应商类型自行注册到注册表。
protocol SuperProviderRegistrant {
    /// 注册到指定的注册表
    static func register(to registry: LLMProviderRegistry)
}
