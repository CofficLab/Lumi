import Foundation

/// 会话行标题的归一规则。
///
/// ## 为什么需要单独一层
///
/// `ConversationSummary.title` 是可选的，但「无标题」在系统里有**三种**形态：
///
/// 1. `nil` —— 读取层归一后的结果（`ConversationModel.toLumiConversationSummary()`
///    把空串归一成 nil）；
/// 2. `""` —— 存储层的必然表示（`ConversationModel.title` 是**非可选** `String`，
///    无标题落库就是空串）；
/// 3. `"   "` —— 未经归一就进入渲染层的纯空白标题。
///
/// `conversation.title ?? "对话"` 只兜得住第 1 种。第 2、3 种既不是 `nil`，
/// `??` 就不生效，于是原样进入渲染层，得到一行**没有任何文字**的会话行：
/// 用户无从辨认这是什么对话，屏幕阅读器会直接跳过它，UI 测试也无法按标题定位。
///
/// 因此标题必须在进入渲染层之前统一归一：无标题一律回退为占位文案。
/// `nil` 与 `""` 两种形态收敛到同一个结果，避免「只堵住其中一种」。
enum ConversationRowTitle {
    /// 无标题时使用的占位文案。
    static let placeholder = "对话"

    /// 归一后的行标题：**永远非空**。
    ///
    /// - Parameter title: 原始标题，可以是 nil、空串或纯空白。
    /// - Returns: 去掉首尾空白的标题；无标题时返回 `placeholder`。
    static func resolve(_ title: String?) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? placeholder : trimmed
    }
}
