import Foundation

/// 能提供**规范化 schema 文本**的工具。
///
/// ## 为什么需要它
///
/// 工具的 `inputSchema` 通常只以 `[String: Any]` 的形态暴露。而 token
/// 估算需要的是 schema 的 JSON 文本长度——调用方只能把刚拿到的字典
/// **重新序列化**一遍（`.sortedKeys`），那一步的成本与解析本身相当。
///
/// 实测（GitHub preset 规模，约 130 个工具）：
///
/// | 环节 | 耗时 |
/// |---|---|
/// | 全量解析 | 1.7–3.3 ms |
/// | 解析后再序列化（token 估算用） | 6.6 ms |
///
/// 这些都在主线程上完成，而真正的网络 I/O 是异步的（Issue #1275）。
///
/// MCP 工具在**注册时**就已经解析好了 schema 并持有规范化文本，实现本
/// 协议即可把那份文本直接交给估算环节，省掉整个「解析→再序列化」往返。
///
/// 本协议是可选的：没实现它的工具走原来的序列化路径，行为不变。
public protocol NormalizedSchemaProviding {
    /// `inputSchema` 的规范化 JSON 文本（键序稳定）。
    ///
    /// 为 `nil` 时调用方应回退到自行序列化。
    var normalizedInputSchemaJSON: String? { get }
}

extension NormalizedSchemaProviding {
    /// 规范化文本；没提供时回退到自行序列化。
    ///
    /// - Important: 必须先用 `isValidJSONObject` 预检，不能只靠 `try?`。
    ///   `JSONSerialization.data(withJSONObject:)` 遇到非 JSON 类型（闭包、
    ///   `Date`、`Data`、`NaN` 等）时抛的是 ObjC `NSException` 而非 Swift
    ///   `Error`，`try?` 捕获不到，会直接 abort 整个进程（signal 6）。
    ///   因此畸形工具 schema 必须先降级为文本估算，而不是让回合崩溃。
    public func normalizedSchemaText(
        for parameters: [String: Any]
    ) -> String {
        if let provided = normalizedInputSchemaJSON {
            return provided
        }
        guard JSONSerialization.isValidJSONObject(parameters),
              let data = try? JSONSerialization.data(
                withJSONObject: parameters,
                options: [.sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8)
        else {
            return String(describing: parameters)
        }
        return text
    }
}
