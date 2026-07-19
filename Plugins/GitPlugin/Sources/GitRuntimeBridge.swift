import LumiKernel

@MainActor
enum GitRuntimeBridge {
    static let gitVM = AppGitVM()
    static var chatServiceProvider: (@MainActor () -> (any LumiChatServicing)?)?
}
