import Foundation
import KitAgentTool

/// 系统权限提示载荷的编解码。
///
/// 与 `ComputerUseAuthorizationCoordinator` 的分工：
/// - 应用级授权需要**挂起回合**等待用户决定，协调器产出 `awaitingUserResponse` 结果；
/// - 系统级权限用户无法在聊天里决定，只能跳转系统设置，因此这里产出
///   **失败**结果（`isError: true`），回合照常推进，LLM 能读到明确原因。
///
/// 载荷随 tool result 的 `content` 传递，原因与授权卡片一致：渲染层只拿到
/// `ToolCall`，没有别的通道能把结构化信息带到 UI。
enum ComputerUseSystemPermissionCoordinator {

    /// 载荷分隔标记。
    ///
    /// 失败结果会作为 `role=tool` 消息回传给 LLM，因此 `content` 必须是
    /// **人类可读**的原因文本；结构化载荷追加在分隔标记之后，供渲染层解析。
    /// 两者共用一个字符串字段，避免为 UI 单独开一条数据通道。
    static let payloadSeparator = "---lumi-computer-use-system-permission---"

    /// 生成携带系统权限载荷的失败结果。
    ///
    /// - Parameters:
    ///   - permission: 缺失的系统权限。
    ///   - operation: 触发本次失败的操作描述。
    /// - Returns: 可直接交给 AgentLoop 的失败结果。
    static func failureResult(
        permission: ComputerUseSystemPermission,
        operation: String
    ) -> ToolCallResult {
        let payload = SystemPermissionPayload(
            kind: ComputerUseSystemPermissionRequest.kind,
            permission: permission,
            operation: operation
        )
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            // 编码失败时不能让用户只看到一句空错误：退回可读的纯文本。
            return ToolCallResult(
                content: permission.missingPermissionMessage,
                isError: true
            )
        }
        return ToolCallResult(
            content: "\(permission.missingPermissionMessage)\n\(payloadSeparator)\n\(json)",
            isError: true
        )
    }

    /// 从 tool result 内容中解析系统权限请求。
    ///
    /// 渲染层用它判断「这条失败结果是不是系统权限提示」，
    /// 只有命中时才接管该行，避免误抢其他工具的失败结果。
    static func request(from content: String) -> ComputerUseSystemPermissionRequest? {
        guard let json = payloadJSON(in: content),
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SystemPermissionPayload.self, from: data),
              payload.kind == ComputerUseSystemPermissionRequest.kind else {
            return nil
        }
        return ComputerUseSystemPermissionRequest(
            permission: payload.permission,
            operation: payload.operation
        )
    }

    /// 从内容中切出分隔标记之后的 JSON 片段。
    ///
    /// 没有分隔标记时返回 `nil`：这类内容不是本协调器产出的，
    /// 渲染层不应误接管。
    private static func payloadJSON(in content: String) -> String? {
        guard let range = content.range(of: payloadSeparator) else { return nil }
        let tail = content[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return tail.isEmpty ? nil : tail
    }
}

/// 系统权限提示在 tool result 中的编码结构。
///
/// 字段刻意压平且保持最小：载荷会随 `content` 一起回传给 LLM，
/// 多余字段就是模型要读的噪音。可读文案不进载荷——它已经在 `content` 的
/// 分隔标记之前。
struct SystemPermissionPayload: Codable, Equatable, Sendable {
    let kind: String
    let permission: ComputerUseSystemPermission
    let operation: String

    enum CodingKeys: String, CodingKey {
        case kind, permission, operation
    }
}
