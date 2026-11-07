import Foundation

/// IdleTime 插件监听的事件通知。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Views/IdleTimeRootObserver.swift` 迁移而来；
/// 新架构在 onBoot 直接注册观察者，不再依赖 root overlay 包装。
public extension Notification.Name {
    /// 编辑器保存事件（由编辑器插件/宿主发布）。
    static let lumiEditorSave = Notification.Name("LumiEditorSave")
}
