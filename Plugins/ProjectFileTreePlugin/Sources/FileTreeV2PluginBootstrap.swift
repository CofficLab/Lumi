import Foundation

/// ProjectFileTreePlugin 的运行时桥接:持有内核数据根目录,
/// 供 `FileTreeSettings` 读取(持久化展开状态)。
///
/// dataRootDirectory 由插件 `onBoot` 从 `kernel.storage?.dataRootDirectory` 注入;
/// 若注入前被访问,使用 Application Support 下的回退目录。
enum ProjectFileTreePluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}
