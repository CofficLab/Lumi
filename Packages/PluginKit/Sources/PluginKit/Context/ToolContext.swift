import Foundation
import AgentToolKit

/// 工具构建上下文
///
/// 在插件工具工厂构建工具时提供的依赖上下文，承载工具所需的全部服务引用。
/// PluginKit 中定义最小化版本，内核在运行时注入完整实现。
@MainActor
public struct ToolContext: AgentToolKit.ToolContextProviding {
    public let languagePreference: LanguagePreference

    public init(languagePreference: LanguagePreference = .english) {
        self.languagePreference = languagePreference
    }
}
