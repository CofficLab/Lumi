import Foundation

/// 工具挂起载荷的「种类」判据。
///
/// ## 为什么需要它
///
/// 工具挂起（`awaitingUserResponse = true`）有两种完全不同的语义：
///
/// | 挂起类型 | 载荷 | 谁来决定 | 需要的授权状态 |
/// |---|---|---|---|
/// | 授权 | 带 `kind` 字段 | 用户点「允许 / 拒绝」 | `pendingAuthorization` |
/// | 交互（如 `ask_user`） | 无 `kind` 字段 | 用户回答问题 | 不需要授权 |
///
/// 两者在消息里的形态几乎一样——都是「挂起结果 + 等待用户」。
/// 仅凭 `authorizationState` / `awaitingUserResponse` **无法区分**二者，
/// 任何据此发起的判断都会误伤。
///
/// 载荷里的 `kind` 字段是唯一可靠的证据：它由**载荷生产者自己**写入，
/// 不依赖工具注册表、风险等级或调用来源。挂起载荷里出现的 `kind` 取值有：
///
/// - `"permission"`：通用工具授权（`ToolManager+Run` 产出）；
/// - `"computer_use_authorization"`：Computer Use 应用授权。
///
/// 两者都是「等用户做一个授权决定」，都需要 `pendingAuthorization`。
///
/// ## 键名陷阱
///
/// 载荷里 `toolCallId` 的键名在不同生产者之间并不统一：有的用
/// `toolCallId`（小写 d），有的用 `toolCallID`（大写 D）。因此本判据
/// **只读 `kind`**——它不依赖那个有争议的键名。
public enum ToolSuspensionKind {
    /// 通用工具授权载荷的种类。
    public static let permission = "permission"

    /// 解析载荷里的 `kind` 字段。
    ///
    /// - Returns: 载荷带 `kind` 字段时返回其值，否则返回 `nil`。
    public static func kind(of content: String?) -> String? {
        guard let content,
              let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let kind = dictionary["kind"] as? String
        else { return nil }
        return kind
    }

    /// 载荷是否表示一次**授权**挂起（等用户做授权决定）。
    ///
    /// 用于「挂起时要不要把授权状态回落成 `pendingAuthorization`」这个判断。
    ///
    /// - Parameter content: 工具结果的 `content`（挂起载荷通常编码在此）。
    /// - Returns: 载荷是授权请求时返回 `true`。
    ///
    /// - Note: 判据是「载荷带 `kind` 字段」。挂起载荷里带 `kind` 的都是
    ///   结构化的授权请求；不带 `kind` 的是交互载荷（如 `ask_user` 的提问
    ///   载荷），它等的是用户的**回答**，不是授权决定。
    public static func isAuthorizationRequest(_ content: String?) -> Bool {
        kind(of: content) != nil
    }

    /// 载荷是否表示**通用**工具授权请求（`kind == "permission"`）。
    ///
    /// 用于通用授权卡片（`ToolApprovalRowRenderer`）判定「该不该由我接管」。
    /// Computer Use 的应用授权载荷（`kind == "computer_use_authorization"`）
    /// 不属于此类——它由 Computer Use 自己的渲染器接管，语义也不同
    /// （「允许一次 / 始终允许 / 拒绝」而非「允许 / 始终允许 / 拒绝」）。
    public static func isPermissionRequest(_ content: String?) -> Bool {
        kind(of: content) == permission
    }

    /// 载荷是否是**结构化**的 JSON 对象。
    ///
    /// 用于区分两类「不是授权载荷」：
    ///
    /// - **结构化但不是授权**（如 `ask_user` 的提问载荷）：JSON 对象，
    ///   明确知道自己是什么，因此可以断言「这不是授权请求」；
    /// - **非结构化**（旧数据里的纯文本内容）：无法判别，不能据此断言，
    ///   只能交给既有的风险等级兜底路径。
    ///
    /// - Note: 数组 / 标量也算「非结构化」——它们不是载荷对象。
    public static func hasStructuredPayload(_ content: String?) -> Bool {
        guard let content,
              let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is [String: Any]
        else { return false }
        return true
    }
}
