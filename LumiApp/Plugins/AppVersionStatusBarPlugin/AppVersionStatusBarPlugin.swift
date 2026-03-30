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
    @State private var build: String = ""

    var body: some View {
        StatusBarHoverContainer(
            detailView: AppVersionDetailView(version: version, build: build),
            id: "app-version-status"
        ) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Text(version)
                    .font(.system(size: 11))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .task {
            await loadVersionInfo()
        }
    }

    private func loadVersionInfo() async {
        version = await AppVersionHelper.getVersion()
        build = await AppVersionHelper.getBuild()
    }
}

// MARK: - App Version Detail View

/// 版本详情视图（在 popover 中显示）
struct AppVersionDetailView: View {
    let version: String
    let build: String

    @State private var appVersion: String = ""
    @State private var buildNumber: String = ""
    @State private var buildDate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("应用版本")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            // 版本信息网格
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                VersionInfoRow(label: "版本号", value: appVersion)
                VersionInfoRow(label: "构建号", value: buildNumber)

                if let buildDate = buildDate {
                    VersionInfoRow(label: "构建日期", value: buildDate)
                }
            }
        }
        .onAppear {
            loadVersionDetails()
        }
    }

    private func loadVersionDetails() {
        appVersion = version
        buildNumber = build

        // 获取构建日期（从 Info.plist 或可执行文件）
        buildDate = getBuildDate()
    }

    private func getBuildDate() -> String? {
        // 尝试从可执行文件获取构建日期
        let bundlePath = Bundle.main.bundlePath
        let url = URL(fileURLWithPath: bundlePath)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: modificationDate)
        }
        return nil
    }
}

/// 版本信息行
struct VersionInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .textSelection(.enabled)

            Spacer()
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
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        }
    }

    /// 获取当前 App 构建号
    /// - Returns: 构建号字符串
    static func getBuild() async -> String {
        await MainActor.run {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        }
    }
}

// MARK: - Preview

#Preview {
    AppVersionStatusBarView()
        .frame(height: 30)
}

#Preview("Detail View") {
    AppVersionDetailView(version: "1.0.0", build: "123")
        .frame(width: 300)
}
