import Foundation

/// 工具挂起载荷（执行层 → 交互层的契约）。
///
/// ## 这是什么
///
/// 工具需要用户做一个决定时（授权或回答问题），执行层把请求编码进
/// `ToolCallResult.content`，回合随之挂起。渲染层与外部宿主（ACP 等）
/// 再从这份内容里把请求恢复出来。
///
/// 这是一份**跨层契约**：生产者（ToolManager）、消费者（渲染层、ACP）
/// 分属不同包。任何一方改动字段名，另一方就会静默失效。
///
/// ## 为什么它属于 KitAgentTool
///
/// 契约必须有唯一归属。过去这份结构在四个包里各抄了一份 `private` 副本，
/// 其中两份还编码出**不同的键名**（`toolCallId` 与 `toolCallID`），
/// 于是同一份契约在生产路径上解码必然失败。
///
/// `KitAgentTool` 是所有相关包共同依赖的最内层，放这里即为唯一真相源。
///
/// ## 键名约定
///
/// 编码一律写 `toolCallId`（小写 d）。历史生产者曾写出 `toolCallID`
/// （大写 D），因此 `decode(from:)` 两种都读；但**新代码只能写小写**。
public struct ToolInteractionPayload: Codable, Equatable, Sendable {
    /// 关联的工具调用 id。授权请求的取值是 `"approval:<toolCallId>"`。
    public let toolCallID: String

    /// 载荷种类。见 `ToolSuspensionKind`。
    public let kind: String

    /// 面向用户的问题正文。
    public let question: String

    /// 用户可选的答案标签。
    public let options: [String]

    /// 交互模式（如 `yes_no` / `choice` / `free_text`）。
    public let mode: String

    enum CodingKeys: String, CodingKey {
        case toolCallID = "toolCallId"
        case kind, question, options, mode
    }

    public init(
        toolCallID: String,
        kind: String,
        question: String,
        options: [String],
        mode: String
    ) {
        self.toolCallID = toolCallID
        self.kind = kind
        self.question = question
        self.options = options
        self.mode = mode
    }

    /// 构造一份工具授权载荷。
    ///
    /// - Parameters:
    ///   - toolCallID: 关联的工具调用 id。
    ///   - riskLevelName: 风险等级显示名（如「高风险」）。
    ///   - operation: 操作描述。
    public static func permission(
        toolCallID: String,
        riskLevelName: String,
        operation: String
    ) -> ToolInteractionPayload {
        ToolInteractionPayload(
            toolCallID: toolCallID,
            kind: ToolSuspensionKind.permission,
            question: "此操作被判定为\(riskLevelName)，是否允许执行？\n\(operation)",
            options: ["允许", "拒绝"],
            mode: "yes_no"
        )
    }

    /// 编码成挂起载荷的 JSON 文本。
    ///
    /// - Returns: JSON 字符串；编码失败时返回一段可读的降级文本
    ///   （它不是合法载荷，消费者会判定「不是授权请求」而不是崩溃）。
    public func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return "Unable to create tool interaction request."
        }
        return text
    }

    /// 从载荷文本里解析出结构化请求。
    ///
    /// - Returns: 载荷是**授权请求**时返回该请求；否则返回 `nil`。
    ///
    /// - Note: 判定一律以 `kind` 为准，不依赖 `toolCallId` 的键名——
    ///   历史生产者曾写出 `toolCallID`（大写 D）。`toolCallID` 本身只是
    ///   展示用的关联标识，取不到时留空也不影响判定。
    public static func decodePermission(from content: String) -> ToolInteractionPayload? {
        guard let dictionary = jsonObject(from: content),
              let kind = dictionary["kind"] as? String,
              kind == ToolSuspensionKind.permission
        else { return nil }

        return ToolInteractionPayload(
            toolCallID: (dictionary["toolCallId"] as? String)
                ?? (dictionary["toolCallID"] as? String)
                ?? "",
            kind: kind,
            question: dictionary["question"] as? String ?? "",
            options: dictionary["options"] as? [String] ?? [],
            mode: dictionary["mode"] as? String ?? "yes_no"
        )
    }

    /// 把载荷文本解析成 JSON 字典。
    ///
    /// - Returns: 载荷是 JSON 对象时返回该字典，否则 `nil`。
    public static func jsonObject(from content: String) -> [String: Any]? {
        guard let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else { return nil }
        return dictionary
    }
}
