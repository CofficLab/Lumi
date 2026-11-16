import Foundation

/// 历史窗口变化的分类（#1330）。
///
/// 消息列表用「尾部 id 是否变化」区分两类内容变化：
/// - 尾部变了：新消息到达 / 首屏加载，可以触发跟随滚到底；
/// - 只有头部变了：prepend（加载更早历史），**不能**触发跟随滚到底，
///   否则视口会跳到会话末尾，用户刚点击的行被甩出屏幕。
public enum HistoryWindowChange {
    /// 本次变化是否带来了新的尾部内容。
    ///
    /// 各列表宿主的边界 id 类型不同（消息/行 id 为 `UUID`，
    /// ChatGPT 的轮次边界为 `String`），故对 `Equatable` 泛型。
    public static func hasNewTail<ID: Equatable>(oldLast: ID?, newLast: ID?) -> Bool {
        newLast != oldLast
    }
}