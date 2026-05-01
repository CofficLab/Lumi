import AppKit
import MagicKit
import SwiftUI

/// 在 Finder 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Finder 中打开当前项目目录。
actor AgentOpenInFinderPlugin: SuperPlugin {
    nonisolated static let emoji = "📂"
    nonisolated static let verbose: Bool = false
    static let id = "AgentOpenInFinder"
    static let displayName = String(localized: "Open in Finder", table: "AgentOpenInFinder")
    static let description = String(localized: "Open current project in Finder", table: "AgentOpenInFinder")
    static let iconName = "folder"
    static var order: Int { 96 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let enable: Bool = true

    static let shared = AgentOpenInFinderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(activeIcon: String?) -> AnyView? {
        return AnyView(OpenInFinderStatusBarView())
    }
}

// MARK: - Status Bar View

/// Finder 打开状态栏视图
struct OpenInFinderStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM

    var body: some View {
        Group {
            if projectVM.currentProjectPath.isEmpty {
                emptyView
            } else {
                hasProjectView
            }
        }
    }

    /// 有项目时的视图
    private var hasProjectView: some View {
        StatusBarHoverContainer(
            detailView: OpenInFinderDetailView(),
            id: "open-in-finder-status"
        ) {
            Button(action: {
                openInFinder()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 Finder 中打开当前项目", table: "AgentOpenInFinder"))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))

            Text("Finder")
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.secondary.opacity(0.5))
        .help(String(localized: "无项目", table: "AgentOpenInFinder"))
    }

    private func openInFinder() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openInFinder()
    }
}

// MARK: - Detail View

/// Finder 打开详情视图（在 popover 中显示）
struct OpenInFinderDetailView: View {
    @EnvironmentObject private var projectVM: ProjectVM

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))

                Text("Finder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Button(action: {
                    openInFinder()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("打开")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("项目")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .frame(width: 50, alignment: .leading)

                Text(projectVM.currentProjectPath)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(projectVM.currentProjectPath, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("复制路径")
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func openInFinder() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openInFinder()
    }
}