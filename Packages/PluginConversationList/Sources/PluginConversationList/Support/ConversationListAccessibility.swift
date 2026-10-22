import Foundation
import ProviderConversation

/// 对话列表的可访问性标识符。
///
/// ## 为什么需要集中在这里
///
/// 会话行此前**没有任何** accessibility 修饰：行是 `Button` 内嵌 `HStack`
/// （标题 + provider + 模型 + 项目 + 时间等若干 `Text`），SwiftUI 不会为这种
/// 组合自动合成带名称的行级元素。后果有两处，且同源：
/// 1. 屏幕阅读器用户读不到会话标题 —— 真实的无障碍缺陷；
/// 2. UI 测试无法按标题定位会话行。
///
/// 标识符放在这里而非 View 内，是为了让 UI 测试（独立 target、不依赖插件模块）
/// 可以引用同一份常量，避免测试里硬编码字符串后与实现漂移。
public enum ConversationListAccessibility {
    /// 单个会话行的标识符（每个行元素共用，按下标/顺序区分）。
    ///
    /// - Note: 不用「标题 + 标识」作为 identifier：标题会随用户编辑而变，
    ///   标识符必须稳定。标题通过 `accessibilityLabel` 暴露。
    public static let itemID = "lumi.conversation-list.item"

    /// 对话列表容器的标识符。
    public static let listID = "lumi.conversation-list"

    /// 组装一行会话的可访问性名称。
    ///
    /// ## 规则
    ///
    /// 1. **标题永远排在最前且一定在场**。标题是这一行唯一稳定、唯一的标识；
    ///    后面的 provider / 模型都可能为空或随时间变化。
    /// 2. 标题为 `nil`、空串或纯空白时回退为「对话」——空 label 会让屏幕阅读器
    ///    跳过该行，也让 UI 测试无法定位，与「没有标识」是同一个缺陷的两面。
    ///    三种「无标题」形态必须收敛到同一个占位文案，否则只堵住其中一种，
    ///    另一种仍然产生空白行（见 `ConversationRowTitle`）。
    /// 3. 空字符串的 provider / 模型一律跳过，避免产生 `"会话 B  "` 这类
    ///    带多余空格的名称（会破坏按标题精确定位的匹配）。
    /// 4. **自动化等级必须显式拼入**。等级标签位于第三行末尾（项目 · 时间 之后），
    ///    与其余元信息一样都是次要信息；但等级本身是这一行的关键状态，
    ///    因此固定拼在 label 尾部，保证屏幕阅读器与 UI 测试都能稳定拿到它。
    ///
    /// - Important: 不能只依赖 `.accessibilityElement(children: .combine)`。
    ///   子元素过多时 SwiftUI 会截断拼接，标题可能被丢掉，因此必须由本函数
    ///   显式产出并赋值。抽成独立函数是为了让这条规则可被单元测试直接锁定 ——
    ///   视图层私有计算属性无法在测试中构造。
    public static func rowLabel(for conversation: ConversationSummary) -> String {
        var parts: [String] = [ConversationRowTitle.resolve(conversation.title)]
        if let providerID = conversation.providerID, !providerID.isEmpty {
            parts.append(providerID)
        }
        if let modelName = conversation.modelName, !modelName.isEmpty {
            parts.append(modelName)
        }
        if let automationLevel = conversation.automationLevel {
            parts.append(automationLevel.displayName)
        }
        return parts.joined(separator: " ")
    }
}
