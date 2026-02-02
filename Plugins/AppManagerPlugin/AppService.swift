import Foundation
import AppKit
import OSLog
import SwiftUI

/// 应用服务
class AppService: ObservableObject {
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "AppService")

    // 标准应用安装路径
    private let standardPaths = [
        "/Applications",
        "/System/Applications",
        "~/Applications",
        "~/Desktop",
    ]

    // 用户特定的应用路径
    private func getUserApplicationPaths() -> [String] {
        var paths = standardPaths

        // 添加其他可能的路径
        if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? {
            paths.append(contentsOf: [
                "\(homeDir)/Downloads",
            ])
        }

        return paths
    }

    /// 扫描已安装的应用（在后台线程执行）
    func scanInstalledApps() async -> [AppModel] {
        return await withCheckedContinuation { continuation in
            // 在后台队列执行文件操作
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    self.logger.info("开始扫描已安装应用")
                    var apps: [AppModel] = []
                    let paths = self.getUserApplicationPaths()

                    for path in paths {
                        let expandedPath = NSString(string: path).expandingTildeInPath
                        guard let url = URL(string: "file://\(expandedPath)") else { continue }

                        if let directoryContents = try? FileManager.default.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: nil,
                            options: [.skipsHiddenFiles]
                        ) {
                            for appURL in directoryContents where appURL.pathExtension == "app" {
                                let app = AppModel(bundleURL: appURL)
                                apps.append(app)
                            }
                        }
                    }

                    let sortedApps = apps.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                    self.logger.info("扫描完成，共找到 \(sortedApps.count) 个应用")
                    continuation.resume(returning: sortedApps)
                }
            }
        }
    }

    /// 计算应用大小（在后台线程执行）
    func calculateAppSize(for app: AppModel) async -> Int64 {
        return await withCheckedContinuation { continuation in
            // 在后台队列执行文件操作
            DispatchQueue.global(qos: .userInitiated).async {
                guard FileManager.default.fileExists(atPath: app.bundleURL.path) else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalSize: Int64 = 0

                if let enumerator = FileManager.default.enumerator(
                    at: app.bundleURL,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                           let fileSize = resourceValues.fileSize {
                            totalSize += Int64(fileSize)
                        }
                    }
                }

                continuation.resume(returning: totalSize)
            }
        }
    }

    /// 卸载应用
    func uninstallApp(_ app: AppModel) async throws {
        logger.info("准备卸载应用: \(app.displayName)")

        let fileManager = FileManager.default
        let appPath = app.bundleURL.path

        // 检查应用是否存在
        guard fileManager.fileExists(atPath: appPath) else {
            logger.error("应用不存在: \(appPath)")
            throw AppError.appNotFound
        }

        // 检查是否有写入权限
        guard fileManager.isWritableFile(atPath: appPath) else {
            logger.error("没有写入权限: \(appPath)")
            throw AppError.permissionDenied
        }

        // 移到废纸篓
        try fileManager.trashItem(at: app.bundleURL, resultingItemURL: nil)
        logger.info("应用已移到废纸篓: \(app.displayName)")
    }

    /// 在 Finder 中显示应用
    func revealInFinder(_ app: AppModel) {
        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
    }

    /// 打开应用
    func openApp(_ app: AppModel) {
        NSWorkspace.shared.open(app.bundleURL)
    }

    /// 获取应用信息
    func getAppInfo(_ app: AppModel) -> String {
        var info = [String]()

        info.append("名称: \(app.displayName)")
        if let identifier = app.bundleIdentifier {
            info.append("Bundle ID: \(identifier)")
        }
        if let version = app.version {
            info.append("版本: \(version)")
        }
        info.append("路径: \(app.bundleURL.path)")

        return info.joined(separator: "\n")
    }
}

enum AppError: LocalizedError {
    case appNotFound
    case permissionDenied
    case uninstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "应用不存在"
        case .permissionDenied:
            return "没有权限卸载此应用"
        case .uninstallFailed(let reason):
            return "卸载失败: \(reason)"
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
