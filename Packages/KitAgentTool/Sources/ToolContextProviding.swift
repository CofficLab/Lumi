import Foundation

/// 工具构建上下文协议
///
/// Package 层定义的协议，App 侧的 `ToolContext` 实现此协议。
/// 让 ToolKit 不直接依赖 App 级 ViewModel 类型。
@MainActor
public protocol ToolContextProviding: Sendable {
    /// 当前语言偏好
    var languagePreference: LanguagePreference { get }
}
