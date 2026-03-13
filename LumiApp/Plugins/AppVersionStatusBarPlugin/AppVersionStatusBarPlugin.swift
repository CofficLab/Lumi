import Foundation
import SwiftUI
import OSLog
import MagicKit

/// 版本状态栏插件：在 Agent 模式底部状态栏显示当前 App 版本
actor AppVersionStatusBarPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "📦"

    /// Whether to enable this plugin
    nonisolated static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = false

    /// Plugin unique identifier
    static let id: String = "AppVersionStatusBar"

    /// Plugin display name
    static let displayName: String = "App 版本"

    /// Plugin functional description
    static let description: String = "在状态栏显示当前应用版本信息"

    /// Plugin icon name
    static let iconName: String = "tag.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order
    static var order: Int { 95 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = AppVersionStatusBarPlugin()

    // MARK: - UI Contributions

    /// Add status bar view for Agent mode
    @MainActor func addStatusBarView() -> AnyView? {
        if Self.verbose {
            os_log("\(self.t) 提供 AppVersionStatusBarView")
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
