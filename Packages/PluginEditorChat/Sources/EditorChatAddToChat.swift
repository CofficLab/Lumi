import Foundation
import KernelLumi

/// 发送方辅助：把引用文本通过 `addToChat` 通知通道投递给聊天输入框。
///
/// 接收端 `ChatPanelPlugin` 的 `ChatComposerSectionView` 监听
/// `LumiEditorNotifications.addToChat`，取 `userInfo["text"]` 追加到草稿，
/// 因此本插件无需改动聊天侧。
@MainActor
enum EditorChatAddToChat {
    static func post(_ text: String, windowId: UUID?) {
        var userInfo: [String: Any] = ["text": text]
        if let windowId {
            userInfo["windowId"] = windowId
        }
        NotificationCenter.default.post(
            name: LumiEditorNotifications.addToChat,
            object: nil,
            userInfo: userInfo
        )
    }
}
