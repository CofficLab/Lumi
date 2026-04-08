import SwiftTerm
import SwiftUI

struct TerminalMainView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @StateObject private var viewModel = TerminalTabsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            HStack(spacing: 0) {
                ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                    TerminalTabItem(
                        title: session.title,
                        isSelected: viewModel.selectedSessionId == session.id,
                        onSelect: { viewModel.selectSession(session.id) },
                        onClose: { viewModel.closeSession(session.id) }
                    )

                    // 标签之间的分隔线（最后一个标签后不加）
                    if index < viewModel.sessions.count - 1 {
                        Rectangle()
                            .fill(AppUI.Color.semantic.textTertiary.opacity(0.3))
                            .frame(width: 1, height: 14)
                            .padding(.horizontal, 2)
                    }
                }

                Button(action: {
                    viewModel.createSession(workingDirectory: currentProjectPathForTerminal)
                }) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                        .appSurface(style: .glass, cornerRadius: AppUI.Radius.sm)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(6)
            .appSurface(style: .glass, cornerRadius: 0)

            // Content - 所有终端视图都保持存在，通过 opacity 控制显示
            // 这样可以避免 Tab 切换时视图被销毁重建导致的状态丢失
            if viewModel.sessions.isEmpty {
                Text("No open terminals")
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
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
            viewModel.updateDefaultWorkingDirectory(currentProjectPathForTerminal)
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
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
