import LumiCoreKit
import LumiUI
import SuperLogKit
import Foundation
import SwiftUI
import TerminalCoreKit
import os

@MainActor
public enum EditorBottomTerminalBridge {
    public static var currentProjectPathProvider: ((PluginContext) -> String?)?
    public static var editorThemeIdProvider: (() -> String)?
}

/// 编辑器底部面板 - Terminal 标签页插件
///
/// 向内核全局底部面板注册 Terminal Tab 入口，
/// 内核负责 Tab 栏渲染和切换，本插件只提供 Tab 定义和内容视图。
///
/// 注意：此插件使用独立的 TerminalTabsViewModel 实例，
/// 与 TerminalPlugin（侧边栏终端）完全隔离，不共享会话状态。
public actor EditorBottomTerminalPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi", category: "plugin.editor-bottom-terminal")

    public nonisolated static let emoji = "💻"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "EditorBottomTerminal"
    public static let displayName: String = String(localized: "Editor Bottom Terminal", bundle: .module)
    public static let description: String = String(localized: "Terminal panel in the editor bottom area", bundle: .module)
    public static let iconName: String = "terminal"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 100 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorBottomTerminalPlugin()

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        EditorBottomTerminalBridge.currentProjectPathProvider = { pluginContext in
            context.currentProjectPath(pluginContext)
        }
        EditorBottomTerminalBridge.editorThemeIdProvider = {
            context.editorThemeId()
        }
    }

    // MARK: - Bottom Panel Tabs

    @MainActor public func addBottomPanelTabs(context: PluginContext) -> [BottomPanelTab] {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return [] }
        return [
            BottomPanelTab(
                id: "editor-bottom-terminal",
                title: String(localized: "Terminal", bundle: .module),
                systemImage: "terminal",
                priority: 100
            ),
        ]
    }

    @MainActor public func addBottomPanelContentView(tabId: String, context: PluginContext) -> AnyView? {
        guard tabId == "editor-bottom-terminal",
              context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(EditorBottomTerminalContentView(context: context))
    }
}

/// Terminal 底部面板内容视图（Editor workspace 挂载点）。
public struct EditorBottomTerminalPanelView: View {
    @LumiTheme private var theme: any LumiUITheme
    @ObservedObject private var viewModel = TerminalTabsViewModel.editorBottomShared

    public init() {}

    private var workingDirectory: String? {
        EditorBottomTerminalBridge.currentProjectPathProvider?(PluginContext())
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar

            if viewModel.sessions.isEmpty {
                emptyState
            } else {
                terminalContent
            }
        }
        .background(theme.background)
        .onAppear {
            viewModel.ensureInitialSession(workingDirectory: workingDirectory)
        }
        .onChange(of: workingDirectory) { _, newValue in
            viewModel.updateDefaultWorkingDirectory(newValue)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                BottomTerminalTabItem(
                    title: session.title,
                    isSelected: viewModel.selectedSessionId == session.id,
                    onSelect: { viewModel.selectSession(session.id) },
                    onClose: { viewModel.closeSession(session.id) }
                )

                if index < viewModel.sessions.count - 1 {
                    Rectangle()
                        .fill(theme.divider.opacity(0.7))
                        .frame(width: 1, height: 14)
                        .padding(.horizontal, 2)
                }
            }

            Button {
                viewModel.createSession(workingDirectory: workingDirectory)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surface.opacity(0.7))
    }

    private var terminalContent: some View {
        ZStack {
            ForEach(viewModel.sessions) { session in
                TerminalSessionContainerView(session: session)
                    .opacity(viewModel.selectedSessionId == session.id ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(theme.textTertiary)
            Text(String(localized: "No open terminals", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textSecondary)
            Button(String(localized: "New Terminal", bundle: .module)) {
                viewModel.createSession(workingDirectory: workingDirectory)
            }
            .font(.appMicroEmphasized)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}

/// Terminal 底部面板内容视图。
///
/// 使用独立的 ViewModel 实例，不与侧边栏 Terminal 共享会话。
private struct EditorBottomTerminalContentView: View {
    let context: PluginContext

    var body: some View {
        EditorBottomTerminalPanelView()
    }
}

private extension TerminalTabsViewModel {
    static let editorBottomShared = TerminalTabsViewModel(
        themeIdProvider: { EditorBottomTerminalBridge.editorThemeIdProvider?() ?? "xcode-dark" }
    )
}

private struct BottomTerminalTabItem: View {
    @LumiTheme private var theme: any LumiUITheme

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
                .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? theme.textPrimary.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
