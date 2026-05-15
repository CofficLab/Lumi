import Foundation

/// 创建主窗口时传递的初始上下文。
///
/// Route 只用于窗口创建阶段；窗口创建后的运行期状态由 WindowState 持有。
struct LumiWindowRoute: Codable, Hashable, Identifiable {
    var id: UUID
    var conversationId: UUID?
    var projectPath: String?

    init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        projectPath: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.projectPath = projectPath
    }
}
