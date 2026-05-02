import Foundation
import MagicKit

/// Go 项目检测器
///
/// 通过向上遍历目录树查找 `go.mod` 文件，定位 Go 项目根目录。
struct GoProjectDetector: SuperLog {
    nonisolated static let emoji = "🔍"

    /// 从给定路径向上查找 go.mod，返回项目根目录路径
    static func findProjectRoot(from path: String) -> String? {
        let fm = FileManager.default
        var current = path

        while true {
            let modPath = (current as NSString).appendingPathComponent("go.mod")
            if fm.fileExists(atPath: modPath) {
                return current
            }

            let parent = (current as NSString).deletingLastPathComponent
            if parent == current { return nil }
            current = parent
        }
    }

    /// 从文件 URL 查找 go.mod 项目根
    static func findProjectRoot(from url: URL) -> String? {
        let dir = url.isDirectory ? url.path : url.deletingLastPathComponent().path
        return findProjectRoot(from: dir)
    }
}

// MARK: - URL Extension

private extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
