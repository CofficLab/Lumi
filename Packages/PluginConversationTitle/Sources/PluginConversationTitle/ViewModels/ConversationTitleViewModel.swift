import Foundation

/// 会话标题 ViewModel：Chat Header 中显示当前会话标题的唯一数据来源。
///
/// 标题来源与旧版一致，由 `ConversationTitleHeaderObserver` 在外部事件到达时
/// 直接写入；视图只读取 `title`，不复制会话标题的回退/持久化规则。
@MainActor
final class ConversationTitleViewModel: ObservableObject {
    @Published private(set) var title = ""

    /// Observer 收到会话事件后调用。
    func update(title: String) {
        guard self.title != title else { return }
        self.title = title
    }
}
