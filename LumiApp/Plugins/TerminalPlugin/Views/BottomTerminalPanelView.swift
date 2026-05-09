import SwiftTerm
import SwiftUI
import LumiUI
import MagicKit

/// 底部终端面板视图
///
/// 在编辑器底部面板区域显示终端，支持多 Tab 会话。
struct BottomTerminalPanelView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var themeVM: ThemeVM

    /// 工作目录（由编辑器状态传递）
    let workingDirectory: String?

    /// 使用全局单例，与侧边栏 Terminal 共享同一份终端会话状态
    @ObservedObject private var viewModel = TerminalTabsViewModel.shared

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
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .onAppear {
            viewModel.ensureInitialSession(workingDirectory: workingDirectory ?? currentProjectPathForTerminal)
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
                        .fill(themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.3))
                        .frame(width: 1, height: 14)
                        .padding(.horizontal, 2)
                }
            }

            // 新建终端按钮
            Button(action: {
                viewModel.createSession(workingDirectory: workingDirectory ?? currentProjectPathForTerminal)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
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
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text("No open terminals")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            Button("New Terminal") {
                viewModel.createSession(workingDirectory: workingDirectory ?? currentProjectPathForTerminal)
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

/// 底部终端 Tab 项 - 紧凑样式
struct BottomTerminalTabItem: View {
    @EnvironmentObject private var themeVM: ThemeVM

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
                    ? themeVM.activeAppTheme.workspaceTextColor()
                    : themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected
                            ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.08)
                            : Color.clear)
                )
            }
            .buttonStyle(.plain)

            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }
}