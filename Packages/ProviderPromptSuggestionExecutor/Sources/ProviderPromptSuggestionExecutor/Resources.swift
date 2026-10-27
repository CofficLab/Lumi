import Foundation

/// 本包的本地化资源 bundle 访问器。
///
/// `Bundle.module` 按词法绑定到书写它的模块：写在执行器源码里会指向本包的
/// 资源 bundle，但写在测试 target 里会指向测试 target 自己（它没有资源）。
/// 需要在包外取用本包本地化资源的调用方，通过本类型取 bundle。
public enum ProviderPromptSuggestionExecutorResources {
    /// 本包（`ProviderPromptSuggestionExecutor`）的资源 bundle。
    public static let bundle: Bundle = .module
}
