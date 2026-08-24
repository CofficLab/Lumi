import Foundation

/// GitHubPlugin 运行时桥接
///
/// 持有 plugin 专属数据目录
enum GitHubInsightRuntimeBridge {
    nonisolated(unsafe) static var rootDirectory: URL?

    static let defaultRoot: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("GitHubInsight", isDirectory: true)
    }()
}