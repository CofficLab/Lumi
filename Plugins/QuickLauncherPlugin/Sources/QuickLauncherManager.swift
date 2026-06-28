import AppKit
import SuperLogKit
import Foundation
import os

/// 快速启动器管理器：负责管理应用启动
@MainActor
public class QuickLauncherManager: SuperLog {
    public nonisolated static let emoji = "🎯"
    public nonisolated static let verbose: Bool = false

    // MARK: - Singleton

    public static let shared = QuickLauncherManager()

    // MARK: - 应用项目

    public struct AppItem: Identifiable {
        public let id = UUID()
        public let name: String
        public let icon: String
        public let bundleIdentifier: String?

        public init(name: String, icon: String, bundleIdentifier: String) {
            self.name = name
            self.icon = icon
            self.bundleIdentifier = bundleIdentifier
        }
    }

    // MARK: - 应用列表（5 个重要系统应用）

    public let apps: [AppItem] = [
        AppItem(name: "Activity Monitor", icon: "waveform.path.ecg", bundleIdentifier: "com.apple.ActivityMonitor"),
        AppItem(name: "System Settings", icon: "gear", bundleIdentifier: "com.apple.SystemSettings"),
        AppItem(name: "Terminal", icon: "terminal", bundleIdentifier: "com.apple.Terminal"),
        AppItem(name: "Disk Utility", icon: "internaldrive", bundleIdentifier: "com.apple.DiskUtility"),
        AppItem(name: "Console", icon: "text.book.closed", bundleIdentifier: "com.apple.Console"),
    ]

    // MARK: - 初始化

    private init() {
        if Self.verbose {
            QuickLauncherPlugin.logger.info("\(self.t)QuickLauncherManager initialized")
        }
    }

    // MARK: - 启动应用

    /// 启动应用
    public func launchApp(_ item: AppItem) {
        guard let bundleId = item.bundleIdentifier else { return }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    QuickLauncherPlugin.logger.error("\(self.t)Failed to launch app: \(error.localizedDescription)")
                }
            }
        } else {
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = ["-b", bundleId]
            do {
                try task.run()
            } catch {
                QuickLauncherPlugin.logger.error("\(self.t)Failed to launch app: \(error.localizedDescription)")
            }
        }
    }
}
