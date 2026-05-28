import LumiCoreKit
import LumiUI
import AppKit
import SwiftUI

/// 在 Finder 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Finder 中打开当前项目目录。
actor AgentOpenInFinderPlugin: SuperPlugin {
    nonisolated static let emoji = "📂"
    nonisolated static let verbose: Bool = true
    static let id = "AgentOpenInFinder"
    static let displayName = String(localized: "Open in Finder", table: "AgentOpenInFinder")
    static let description = String(localized: "Open current project in Finder", table: "AgentOpenInFinder")
    static let iconName = "folder"
    static var category: PluginCategory { .integration }
    static var order: Int { 96 }
    static let policy: PluginPolicy = .optOut

    /// 用户可在设置中启用/禁用此插件

    static let shared = AgentOpenInFinderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(OpenInFinderStatusBarView())
    }
}

// MARK: - Status Bar View

/// Finder 打开状态栏视图
struct OpenInFinderStatusBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

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
                        .font(.appCaption)
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
                .font(.appMicro)

            Text(String(localized: "Finder", table: "OpenInFinderPlugin"))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
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
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Text(String(localized: "Finder", table: "OpenInFinderPlugin"))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInFinder()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(String(localized: "打开", table: "OpenInFinderPlugin"))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(String(localized: "项目", table: "OpenInFinderPlugin"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 50, alignment: .leading)

                Text(projectVM.currentProjectPath)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(projectVM.currentProjectPath, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.appCaption)
                }
                .buttonStyle(.plain)
                .help(String(localized: "复制路径", table: "OpenInFinderPlugin"))
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
