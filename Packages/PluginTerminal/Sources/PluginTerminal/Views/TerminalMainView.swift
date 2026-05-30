import SwiftTerm
import SwiftUI
import LumiCoreKit
import LumiUI
import TerminalCoreKit

public struct TerminalMainView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject private var projectVM: WindowProjectVM
    /// 使用全局单例，无论 TerminalMainView 被重建多少次，都共享同一份终端会话状态。
    @ObservedObject private var viewModel = TerminalTabsViewModel.shared

    private var indexedSessions: [(offset: Int, session: TerminalSession)] {
        viewModel.sessions.enumerated().map { (offset: $0.offset, session: $0.element) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(indexedSessions, id: \.session.id) { item in
                    TerminalTabItem(
                        title: item.session.title,
                        isSelected: viewModel.selectedSessionId == item.session.id,
                        onSelect: { viewModel.selectSession(item.session.id) },
                        onClose: { viewModel.closeSession(item.session.id) }
                    )

                    // 标签之间的分隔线（最后一个标签后不加）
                    if item.offset < viewModel.sessions.count - 1 {
                        Rectangle()
                            .fill(theme.divider)
                            .frame(width: 1, height: 14)
                            .padding(.horizontal, 2)
                    }
                }

                Button(action: {
                    viewModel.createSession(workingDirectory: currentProjectPathForTerminal)
                }) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                        .appSurface(style: .glass, cornerRadius: 8)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(6)
            .appSurface(style: .glass, cornerRadius: 0)

            // Content - 所有终端视图都保持存在，通过 opacity 控制显示
            // 这样可以避免 Tab 切换时视图被销毁重建导致的状态丢失
            if viewModel.sessions.isEmpty {
                Text(String(localized: "No open terminals", table: "Terminal"))
                    .font(.appBody)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    ForEach(viewModel.sessions) { session in
                        TerminalSessionContainerView(session: session)
                            .opacity(viewModel.selectedSessionId == session.id ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            viewModel.ensureInitialSession(workingDirectory: currentProjectPathForTerminal)
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            viewModel.updateDefaultWorkingDirectory(currentProjectPathForTerminal)
        }
    }

    private var currentProjectPathForTerminal: String? {
        let path = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
