import AppKit
import MagicKit
import SwiftUI

/// 在 Cursor 中打开项目插件
///
/// 在 Agent 模式的状态栏左侧添加图标，点击后在 Cursor 编辑器中打开当前项目。
actor AgentOpenInCursorPlugin: SuperPlugin {
    nonisolated static let emoji = "↗️"
    nonisolated static let verbose = false

    static let id = "AgentOpenInCursor"
    static let displayName = String(localized: "Open in Cursor", table: "AgentOpenInCursor")
    static let description = String(localized: "Open current project in Cursor editor", table: "AgentOpenInCursor")
    static let iconName = "chevron.left.forwardslash.chevron.right"
    static var order: Int { 82 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    /// 默认启用
    static var enable: Bool { true }

    static let shared = AgentOpenInCursorPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - Status Bar

    /// 添加状态栏左侧视图
    @MainActor
    func addStatusBarLeadingView() -> AnyView? {
        return AnyView(OpenInCursorStatusBarView())
    }
}

// MARK: - Status Bar View

/// Cursor 打开状态栏视图
struct OpenInCursorStatusBarView: View {
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
            detailView: OpenInCursorDetailView(),
            id: "open-in-cursor-status"
        ) {
            Button(action: {
                openInCursor()
            }) {
                HStack(spacing: 6) {
                    Image.cursorApp
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help(String(localized: "在 Cursor 中打开当前项目", bundle: .main))
        }
    }

    /// 无项目时的视图
    private var emptyView: some View {
        HStack(spacing: 6) {
            Image.cursorApp
                .resizable()
                .frame(width: 10, height: 10)

            Text("Cursor")
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.secondary.opacity(0.5))
        .help(String(localized: "无项目", table: "AgentOpenInCursor"))
    }

    private func openInCursor() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.cursor)
    }
}

// MARK: - Detail View

/// Cursor 打开详情视图（在 popover 中显示）
struct OpenInCursorDetailView: View {
    @EnvironmentObject private var projectVM: ProjectVM

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image.cursorApp
                    .resizable()
                    .frame(width: 16, height: 16)

                Text("Cursor")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Button(action: {
                    openInCursor()
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

    private func openInCursor() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.cursor)
    }
}
