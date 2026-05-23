import LumiUI
import AppKit
import SwiftUI

/// 在 Antigravity 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Antigravity 编辑器中打开当前项目。
actor AgentOpenInAntigravityPlugin: SuperPlugin {
    nonisolated static let emoji = "🚀"
    nonisolated static let verbose: Bool = false
    static let id = "AgentOpenInAntigravity"
    static let displayName = String(localized: "Open in Antigravity", table: "AgentOpenInAntigravity")
    static let description = String(localized: "Open current project in Antigravity editor", table: "AgentOpenInAntigravity")
    static let iconName = "paperplane"
    static var category: PluginCategory { .integration }
    static var order: Int { 83 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    /// 默认禁用（需要用户主动启用）
    static var enable: Bool { true }

    static let shared = AgentOpenInAntigravityPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView(activeIcon: String?) -> AnyView? {
        return AnyView(OpenInAntigravityStatusBarView())
    }
}

// MARK: - Status Bar View

/// Antigravity 打开状态栏视图
struct OpenInAntigravityStatusBarView: View {
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
            detailView: OpenInAntigravityDetailView(),
            id: "open-in-antigravity-status"
        ) {
            Button(action: {
                openInAntigravity()
            }) {
                HStack(spacing: 6) {
                    Image.antigravityApp
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 Antigravity 中打开当前项目", bundle: .main))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image.antigravityApp
                .resizable()
                .frame(width: 10, height: 10)

            Text(String(localized: "Antigravity", table: "OpenInAntigravityPlugin"))
                .font(.appMicro)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(theme.textSecondary.opacity(0.5))
        .help(String(localized: "无项目", table: "AgentOpenInAntigravity"))
    }

    private func openInAntigravity() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.antigravity)
    }
}

// MARK: - Detail View

/// Antigravity 打开详情视图（在 popover 中显示）
struct OpenInAntigravityDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image.antigravityApp
                    .resizable()
                    .frame(width: 16, height: 16)

                Text(String(localized: "Antigravity", table: "OpenInAntigravityPlugin"))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button(action: {
                    openInAntigravity()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text(String(localized: "打开", table: "OpenInAntigravityPlugin"))
                    }
                    .font(.appCaption)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // 项目路径显示
            HStack(spacing: 8) {
                Text(String(localized: "项目", table: "OpenInAntigravityPlugin"))
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
                .help(String(localized: "复制路径", table: "OpenInAntigravityPlugin"))
            }
        }
        .padding()
        .frame(width: 320)
    }

    private func openInAntigravity() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.antigravity)
    }
}
