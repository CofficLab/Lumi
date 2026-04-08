import SwiftUI
import SwiftTerm

struct TerminalMainView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @StateObject private var viewModel = TerminalTabsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(viewModel.sessions) { session in
                        TerminalTabItem(
                            title: session.title,
                            isSelected: viewModel.selectedSessionId == session.id,
                            onSelect: { viewModel.selectSession(session.id) },
                            onClose: { viewModel.closeSession(session.id) }
                        )
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
            }
            .appSurface(style: .glass, cornerRadius: AppUI.Radius.sm)
            
            // Content
            if let session = viewModel.selectedSession {
                TerminalSessionContainerView(session: session)
                    .id(session.id)
            } else {
                Text("No open terminals")
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
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

struct TerminalTabItem: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(isSelected ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)
            
            if isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundShape)
        .onTapGesture {
            onSelect()
        }
    }

    @ViewBuilder
    var backgroundShape: some View {
        if isSelected {
            Color.clear
                .appSurface(style: .glass, cornerRadius: AppUI.Radius.sm)
        } else {
            Color.clear
        }
    }
}

struct TerminalSessionContainerView: View {
    @ObservedObject var session: TerminalSession
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NativeTerminalHostView(session: session)
        .background(colorScheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : .white
        )
    }
}

struct NativeTerminalHostView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        // SwiftTerm 终端会话是长生命周期对象，直接复用对应的 NSView。
        session.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
}

@MainActor
final class TerminalTabsViewModel: ObservableObject {
    @Published var sessions: [TerminalSession] = []
    @Published var selectedSessionId: UUID?
    private var defaultWorkingDirectory: String?
    
    init() {
        createSession(workingDirectory: defaultWorkingDirectory)
    }
    
    var selectedSession: TerminalSession? {
        sessions.first(where: { $0.id == selectedSessionId })
    }
    
    func createSession(workingDirectory: String?) {
        let session = TerminalSession(workingDirectory: workingDirectory ?? defaultWorkingDirectory)
        sessions.append(session)
        selectedSessionId = session.id
    }

    func updateDefaultWorkingDirectory(_ path: String?) {
        defaultWorkingDirectory = path
    }
    
    func selectSession(_ id: UUID) {
        selectedSessionId = id
    }
    
    func closeSession(_ id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            let session = sessions[index]
            session.terminate()
            sessions.remove(at: index)

            if selectedSessionId == id {
                selectedSessionId = sessions.last?.id
            }
        }
    }

}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
