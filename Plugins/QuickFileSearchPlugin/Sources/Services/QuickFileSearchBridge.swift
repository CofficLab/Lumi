import Foundation

/// 文件搜索桥接
///
/// 解耦搜索服务与内核：插件在 `onReady` 中注入实际 handler，
/// 服务层只通过此桥接调用，不直接依赖 KernelLumi。
@MainActor
public enum QuickFileSearchBridge {
    /// 选中文件后的回调：(filePath, windowId?)
    public static var selectFileHandler: ((String, UUID?) -> Void)?

    /// 获取当前活跃窗口 ID
    public static var activeWindowIdProvider: (() -> UUID?)?
}
