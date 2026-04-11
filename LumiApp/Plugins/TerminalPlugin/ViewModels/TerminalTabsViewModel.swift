import Foundation

@MainActor
final class TerminalTabsViewModel: ObservableObject {
    @Published var sessions: [TerminalSession] = []
    @Published var selectedSessionId: UUID?
    private var defaultWorkingDirectory: String?

    init() {}

    /// 确保至少有一个终端会话，使用指定的工作目录
    func ensureInitialSession(workingDirectory: String?) {
        defaultWorkingDirectory = workingDirectory
        if sessions.isEmpty {
            createSession(workingDirectory: workingDirectory)
        }
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
