import Foundation

/// 终端 Tab 视图模型
///
/// 管理多个终端会话的 Tab 状态，包括：
/// - 会话创建、选择、关闭
/// - 默认工作目录管理
///
/// 注意：每个使用场景应创建独立的 ViewModel 实例，
/// 而不是使用共享单例。
@MainActor
public final class TerminalTabsViewModel: ObservableObject {
    @Published public var sessions: [TerminalSession] = []
    @Published public var selectedSessionId: UUID?
    private var defaultWorkingDirectory: String?

    /// 主题 ID 提供者
    private let themeIdProvider: () -> String

    /// 初始化
    ///
    /// - Parameter themeIdProvider: 主题 ID 提供者回调
    public init(themeIdProvider: @escaping () -> String = { "xcode-dark" }) {
        self.themeIdProvider = themeIdProvider
    }

    /// 确保至少有一个终端会话，使用指定的工作目录
    public func ensureInitialSession(workingDirectory: String?) {
        defaultWorkingDirectory = workingDirectory
        if sessions.isEmpty {
            createSession(workingDirectory: workingDirectory)
        }
    }

    public var selectedSession: TerminalSession? {
        sessions.first(where: { $0.id == selectedSessionId })
    }

    public func createSession(workingDirectory: String?) {
        let session = TerminalSession(
            workingDirectory: workingDirectory ?? defaultWorkingDirectory,
            themeId: themeIdProvider(),
            themeIdProvider: themeIdProvider
        )
        sessions.append(session)
        selectedSessionId = session.id
    }

    public func updateDefaultWorkingDirectory(_ path: String?) {
        defaultWorkingDirectory = path
    }

    public func selectSession(_ id: UUID) {
        selectedSessionId = id
    }

    public func closeSession(_ id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            let session = sessions[index]
            session.terminate()
            sessions.remove(at: index)

            if selectedSessionId == id {
                selectedSessionId = sessions.last?.id
            }
        }
    }

    /// 更新所有会话的主题
    public func updateThemeForAllSessions(_ themeId: String) {
        for session in sessions {
            session.updateTheme(themeId)
        }
    }
}