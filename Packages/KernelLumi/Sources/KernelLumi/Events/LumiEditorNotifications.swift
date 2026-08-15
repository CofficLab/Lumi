import Foundation

/// 编辑器相关的跨插件通知名（迁移期兼容）。
///
/// Phase 3（重构方案 §18.2）：`EditorContext` 已随 FileTree/TabStrip 协同协议删除，
/// 其承载的“加入对话”通知是 Problems → Chat 的跨插件桥，常量移到内核中立位置。
/// 最终形态由 `EditorContextProviding`（Agent 编辑闭环，Phase 9）取代。
public enum LumiEditorNotifications {
    /// “把文本加入当前对话草稿”通知名。
    /// `userInfo["text"]` 为要追加的文本；`userInfo["windowId"]` 为可选目标窗口。
    public static let addToChat = Notification.Name("LumiEditor.addToChat")
}
