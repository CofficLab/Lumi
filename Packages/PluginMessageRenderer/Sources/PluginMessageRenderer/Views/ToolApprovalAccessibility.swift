import Foundation

/// 工具授权卡片的无障碍标识符。
///
/// 命名沿用仓库既有惯例（见 `AskUserAccessibility`）。
enum ToolApprovalAccessibility {
    /// 授权卡片容器。出现即代表有一个待用户处理的授权请求。
    static let card = "lumi.tool-approval.card"

    /// 授权问题正文。
    static let question = "lumi.tool-approval.question"

    /// 「允许」按钮。
    static let allow = "lumi.tool-approval.allow"

    /// 「始终允许」按钮。
    static let alwaysAllow = "lumi.tool-approval.always-allow"

    /// 「拒绝」按钮。
    static let reject = "lumi.tool-approval.reject"

    /// 不属于上述三种决定的按钮（兜底）。
    static let other = "lumi.tool-approval.other"
}
