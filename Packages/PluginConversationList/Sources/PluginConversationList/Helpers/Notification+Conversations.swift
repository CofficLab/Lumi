import Foundation

extension Notification.Name {
    /// 对话列表变更通知：与旧版 KernelLumi 通知名完全一致，
    /// 由 PluginConversationManager 的 ConversationManager 广播，
    /// 新版列表视图据此刷新（复刻旧版 `onLumiConversationsDidChange`）。
    static let lumiConversationsDidChange = Notification.Name("com.coffic.lumi.conversationsDidChange")
}
