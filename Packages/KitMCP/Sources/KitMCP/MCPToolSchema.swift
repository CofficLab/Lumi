import Foundation

/// 一个工具的输入 schema（已解析、可复用）。
///
/// ## 为什么要有这个类型
///
/// MCP 的 `inputSchema` 以 JSON **字符串**形式保存。上层需要
/// `[String: Any]` 时只能重新 `JSONSerialization` 解析，而工具 schema
/// 在 `listTools` 之后是**静态**的——每个 LLM 请求、每次工具调用续轮、
/// 每次上下文重试都重新解析一遍同样的字节。
///
/// 实测（GitHub preset 规模，约 130 个工具，每个 schema 约 700 字节）：
///
/// | 环节 | 耗时 |
/// |---|---|
/// | 全量解析 | 1.7–3.3 ms |
/// | 解析后再序列化（token 估算用） | 6.6 ms |
///
/// 这些工作全部发生在主线程上，而真正的网络 I/O 是异步的（Issue #1275）。
///
/// ## 一次性算好，之后零成本
///
/// 本类型在构造时完成两件事：
///
/// 1. 解析出 `[String: Any]`（供 `SuperAgentTool.inputSchema` 使用）；
/// 2. 序列化出**规范化** JSON 文本（键序稳定，`.sortedKeys`），供 token
///    估算直接使用，避免「解析完又序列化回去」的往返。
///
/// 之后每次访问都是 O(1) 的字段读取。
///
/// ## 关于 Sendable
///
/// `[String: Any]` 本身不满足 `Sendable`（`Any` 无并发保证）。但 JSON
/// 解析出的对象在构造完成后**不再被修改**，跨线程只读传递是安全的，
/// 因此这里用 `@unchecked Sendable` 承担这个责任。
public struct MCPToolSchema: @unchecked Sendable {

    /// 解析后的 schema 对象。
    ///
    /// 解析失败时为 `nil`，调用方回退到空 schema。
    public let parameters: [String: Any]?

    /// 规范化后的 JSON 文本（键序稳定）。
    ///
    /// 用于 token 估算：估算只需要 JSON 文本的字节数，不必每次重新序列化。
    /// 解析失败时为 `nil`。
    public let normalizedJSON: String?

    /// 解析失败时使用的空 schema。
    ///
    /// 刻意做成计算属性而非 `static let`：`[String: Any]` 不满足 `Sendable`，
    /// 作为全局静态常量在 Swift 6 严格并发下不合法。每次返回新字典也
    /// 避免了调用方意外改到共享状态。
    public static var emptyParameters: [String: Any] {
        ["type": "object", "properties": [:]]
    }

    /// 解析一段 schema JSON。
    ///
    /// - Parameter json: schema 的 JSON 字符串。
    public init(json: String) {
        guard
            let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            self.parameters = nil
            self.normalizedJSON = nil
            return
        }
        self.parameters = object
        // 规范化文本与参数一一对应：估算用的字节数与实际发出去的 JSON
        // 完全一致，避免估算偏大或偏小。
        self.normalizedJSON = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    /// 解析后的 schema 对象；解析失败时回退到空 schema。
    public var resolvedParameters: [String: Any] {
        parameters ?? Self.emptyParameters
    }

    /// 规范化 JSON 文本的字节数（token 估算用）。
    ///
    /// 解析失败时返回 0——此时没有任何 schema 内容可估算。
    public var normalizedByteCount: Int {
        normalizedJSON?.utf8.count ?? 0
    }
}
