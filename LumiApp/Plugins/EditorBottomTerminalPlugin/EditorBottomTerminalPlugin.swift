import LumiCoreKit
import Foundation
import SwiftUI
import TerminalCoreKit
import os

/// 编辑器底部面板 - Terminal 标签页插件
///
/// 向内核全局底部面板注册 Terminal Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
///
/// 注意：此插件使用独立的 TerminalTabsViewModel 实例，
/// 与 TerminalPlugin（侧边栏终端）完全隔离，不共享会话状态。
actor EditorBottomTerminalPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-terminal")

    nonisolated static let emoji = "💻"
    nonisolated static let verbose: Bool = true
    static let id: String = "EditorBottomTerminal"
    static let displayName: String = String(
        localized: "Editor Bottom Terminal", table: "EditorBottomTerminal")
    static let description: String = String(
        localized: "Terminal panel in the editor bottom area", table: "EditorBottomTerminal")
    static let iconName: String = "terminal"
    static var category: PluginCategory { .editor }
    static var order: Int { 100 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorBottomTerminalPlugin()

    // MARK: - Bottom Panel Tabs

    @MainActor func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        // Terminal Tab 仅在编辑器激活时显示
        guard context.activeIcon == EditorPlugin.iconName else { return [] }
        return [BottomPanelTab(
            id: "editor-bottom-terminal",
            title: String(localized: "Terminal", table: "EditorBottomTerminal"),
            systemImage: "terminal",
            priority: 100
        )]
    }

    @MainActor func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-terminal", context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorBottomTerminalContentView())
    }
}

/// Terminal 底部面板内容视图
///
/// 使用独立的 ViewModel 实例，不与侧边栏 Terminal 共享会话。
struct EditorBottomTerminalContentView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 底部面板专用共享实例，避免 bottom tab 内容视图重建时丢失终端会话。
    @ObservedObject private var viewModel = TerminalTabsViewModel.editorBottomShared

    /// 工作目录（使用当前项目根路径）
    private var workingDirectory: String? {
        currentProjectPathForTerminal
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar - 紧凑样式适配底部面板
            tabBar

            // Content - 所有终端视图都保持存在，通过 opacity 控制显示
            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                terminalContent
            }
        }
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .onAppear {
            viewModel.ensureInitialSession(workingDirectory: workingDirectory)
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            viewModel.updateDefaultWorkingDirectory(workingDirectory)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiThemeDidChange)) { notification in
            // 监听主题变化，更新所有会话的主题
            if let editorThemeId = notification.userInfo?["editorThemeId"] as? String {
                viewModel.updateThemeForAllSessions(editorThemeId)
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                BottomTerminalTabItem(
                    title: session.title,
                    isSelected: viewModel.selectedSessionId == session.id,
                    onSelect: { viewModel.selectSession(session.id) },
                    onClose: { viewModel.closeSession(session.id) }
                )

                // 标签之间的分隔线
                if index < viewModel.sessions.count - 1 {
                    Rectangle()
                        .fill(themeVM.activeChromeTheme.workspaceSecondaryTextColor().opacity(0.3))
                        .frame(width: 1, height: 14)
                        .padding(.horizontal, 2)
                }
            }

            // 新建终端按钮
            Button(action: {
                viewModel.createSession(workingDirectory: workingDirectory)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        ZStack {
            ForEach(viewModel.sessions) { session in
                TerminalSessionContainerView(session: session)
                    .opacity(viewModel.selectedSessionId == session.id ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeVM.activeChromeTheme.workspaceTertiaryTextColor())
            Text(String(localized: "No open terminals", table: "EditorBottomTerminal"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            Button(String(localized: "New Terminal", table: "EditorBottomTerminal")) {
                viewModel.createSession(workingDirectory: workingDirectory)
            }
            .font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helpers

    private var currentProjectPathForTerminal: String? {
        let path = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}

private extension TerminalTabsViewModel {
    /// Editor bottom terminal 使用自己的共享实例，与侧边栏 Terminal 保持会话隔离。
    static let editorBottomShared = TerminalTabsViewModel(
        themeIdProvider: { AppThemeVM.currentEditorThemeId() }
    )
}

/// 底部终端 Tab 项 - 紧凑样式
struct BottomTerminalTabItem: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onSelect) {
                HStack(spacing: 4) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9, weight: .semibold))
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundColor(isSelected
                    ? themeVM.activeChromeTheme.workspaceTextColor()
                    : themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected
                            ? themeVM.activeChromeTheme.workspaceTextColor().opacity(0.08)
                            : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
