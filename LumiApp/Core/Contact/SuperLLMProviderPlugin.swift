import Foundation

/// LLM 供应商插件协议（超级接口）
///
/// - 不参与 UI，只负责把一个或多个 `SuperLLMProvider` 类型注册到 `ProviderRegistry`。
/// - 由运行时扫描所有以 `LLMPlugin` 结尾的类，调用其 `registerProviders(to:)` 完成注册。
protocol SuperLLMProviderPlugin: AnyObject {

    /// 是否启用此插件
    ///
    /// 允许通过静态开关快速关闭某个 LLM 插件。
    static var enable: Bool { get }

    /// 插件加载顺序（数字越小越先注册）
    static var order: Int { get }

    /// 向注册表注册当前插件提供的一个或多个 LLM 供应商类型
    ///
    /// - Parameter registry: 供应商注册表
    static func registerProviders(to registry: ProviderRegistry)
}

