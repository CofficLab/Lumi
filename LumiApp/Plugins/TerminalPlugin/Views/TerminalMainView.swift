import SwiftUI

struct TerminalMainView: View {
    @StateObject private var viewModel = TerminalManagerViewModel()
    
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
                        viewModel.createSession()
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
                TerminalView(session: session)
            } else {
                Text("No open terminals")
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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

struct TerminalView: View {
    @ObservedObject var session: TerminalSession
    
    var body: some View {
        ConsoleTextView(text: $session.output, onInput: { data in
            session.sendInput(data)
        })
        .background(AppUI.Color.basePalette.deepBackground)
    }
}

@MainActor
class TerminalManagerViewModel: ObservableObject {
    @Published var sessions: [TerminalSession] = []
    @Published var selectedSessionId: UUID?
    
    init() {
        createSession()
    }
    
    var selectedSession: TerminalSession? {
        sessions.first(where: { $0.id == selectedSessionId })
    }
    
    func createSession() {
        let session = TerminalSession()
        sessions.append(session)
        selectedSessionId = session.id
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
