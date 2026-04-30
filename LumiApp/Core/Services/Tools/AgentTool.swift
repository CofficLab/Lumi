import Foundation

/// 工具参数包装器
///
/// 用于在工具调用时传递参数的包装类型。
/// 使用 `@unchecked Sendable` 来抑制并发警告，
/// 因为参数值可能是任意类型。
public struct ToolArgument: @unchecked Sendable {
    /// 参数的实际值
    public let value: Any
    
    /// 初始化工具参数
    ///
    /// - Parameter value: 任意类型的参数值
    public init(_ value: Any) { self.value = value }
}
