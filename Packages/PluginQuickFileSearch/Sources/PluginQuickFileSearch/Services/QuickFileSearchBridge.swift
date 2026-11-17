import Foundation

/// 文件搜索桥接
///
/// 解耦搜索服务与内核：插件在 `onReady` 中注入实际 handler，
/// 服务层只通过此桥接调用，不直接依赖 KernelLumi。
@MainActor
public enum QuickFileSearchBridge {
    /// 选中文件后的回调：(filePath, windowId?) async -> Bool
    ///
    /// 返回 `true` 表示打开请求已被内核接受；`false` 表示失败
    /// （provider 缺失或 `open` 抛错）。调用方据此决定收起面板还是
    /// 保留可重试状态并显式报告错误（#187）。handler 未注入时视为失败。
    public static var selectFileHandler: (@MainActor (String, UUID?) async -> Bool)?

    /// 获取当前活跃窗口 ID
    public static var activeWindowIdProvider: (() -> UUID?)?
}
