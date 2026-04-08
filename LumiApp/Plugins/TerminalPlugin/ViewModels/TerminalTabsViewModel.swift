import Foundation

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
