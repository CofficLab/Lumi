import Foundation

@MainActor
final class TerminalTabsViewModel: ObservableObject {
    /// 全局单例，确保终端会话在整个应用生命周期中保持不变，
    /// 即使 SwiftUI 重建 TerminalMainView 也不会丢失状态。
    static let shared = TerminalTabsViewModel()

    @Published var sessions: [TerminalSession] = []
    @Published var selectedSessionId: UUID?
    private var defaultWorkingDirectory: String?

    private init() {}

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
