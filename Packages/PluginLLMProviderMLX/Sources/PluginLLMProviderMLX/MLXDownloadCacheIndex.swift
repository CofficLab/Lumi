import Foundation

/// 下载缓存的磁盘扫描索引。
///
/// ## 为什么需要它
///
/// 远程模型下载时，底层下载器每写入 64KB 就回调一次进度；4GiB 的模型
/// 会累积约 65,536 次回调。下载状态的完整求值包含：
/// - 对每个可用模型做完成标记与目录检查；
/// - 递归枚举整个模型缓存目录并读取每个文件的大小。
///
/// 这些操作全部在主线程执行，逐次执行会把进度事件放大成持续的磁盘
/// I/O 风暴，表现为下载界面卡顿、进度滞后与其它界面响应变慢。
///
/// 因此扫描结果必须**缓存**：只在结构性变化（完成 / 删除 / 取消 /
/// 显式刷新）时重算，进度事件只读缓存。
@MainActor
final class MLXDownloadCacheIndex {

    /// 一次磁盘扫描的结果。
    struct Snapshot: Equatable {
        /// 已下载（完整）的模型 ID。
        var downloadedModelIDs: Set<String>
        /// 缓存目录的总字节数。
        var cacheSizeBytes: Int64
    }

    /// 已缓存的扫描结果。
    private(set) var snapshot: Snapshot?

    /// 已完成的磁盘扫描次数。
    ///
    /// 诊断与回归测试用：进度事件不应让它增长。
    private(set) var scanCount = 0

    /// 作废缓存：下次读取时重新扫描磁盘。
    ///
    /// 只在结构性变化时调用——下载完成、删除模型、取消、显式刷新、
    /// 以及模型根目录变更。
    func invalidate() {
        snapshot = nil
    }

    /// 取扫描结果；缓存无效时才真正扫描一次。
    func snapshot(using scan: () -> Snapshot) -> Snapshot {
        if let snapshot {
            return snapshot
        }
        scanCount += 1
        let scanned = scan()
        snapshot = scanned
        return scanned
    }
}
