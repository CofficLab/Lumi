import Foundation

/// 扫描控制栏可见性（#849）。
///
/// 五个扫描界面（系统缓存 / 目录分析 / 大文件 / 项目清理 / Xcode 清理）的控制栏内含
/// 唯一的 Stop 分支：`isScanning` 时显示 Stop 并调用 `stopScan()`。此前父视图在
/// `isScanning` 时隐藏整个控制栏（大文件还在扫描开始时清空结果），导致扫描进行中
/// 唯一的取消入口不可达，用户只能等扫描结束或离开页面。
///
/// 统一约定：扫描进行中必须保留控制栏（Stop 可达）；扫描结束后有结果时显示
/// Start/Refresh；空闲且无结果时隐藏。
enum ScanControlBarVisibility {
    static func isVisible(isScanning: Bool, hasResults: Bool) -> Bool {
        isScanning || hasResults
    }
}