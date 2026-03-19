import MagicKit
import SwiftUI
import Foundation
import os

/// 版本状态栏插件：在 Agent 模式底部状态栏显示当前 App 版本
actor AppVersionStatusBarPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-version-status-bar")
    // MARK: - Plugin Properties

    nonisolated static let emoji = "📦"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "AppVersionStatusBar"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "App Version", table: "AppVersionStatusBar")
    static let description: String = String(localized: "Display current app version in status bar", table: "AppVersionStatusBar")
    static let iconName: String = "tag.fill"
    static let isConfigurable: Bool = false
    static var order: Int { 95 }

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppVersionStatusBarPlugin()

    // MARK: - UI Contributions

    /// Add status bar view for Agent mode
    @MainActor func addStatusBarView() -> AnyView? {
        if Self.verbose {
            AppVersionStatusBarPlugin.logger.info("\(Self.t)提供 AppVersionStatusBarView")
        }
        return AnyView(AppVersionStatusBarView())
    }
}

// MARK: - Status Bar View

/// App 版本状态栏视图
struct AppVersionStatusBarView: View {
    /// 当前 App 版本号
    @State private var version: String = "Unknown"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "tag.fill")
                .font(.system(size: 10))
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)

            Text(version)
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .task {
            version = await AppVersionHelper.getVersion()
        }
    }
}

// MARK: - App Version Helper

/// App 版本辅助工具
enum AppVersionHelper {
    /// 获取当前 App 版本号
    /// - Returns: 版本号字符串（例如："1.0.0"）
    static func getVersion() async -> String {
        await MainActor.run {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

            if build.isEmpty || build == "1" {
                return version
            }
            return "\(version) (\(build))"
        }
    }
}

// MARK: - Preview

#Preview {
    AppVersionStatusBarView()
        .frame(height: 30)
}
