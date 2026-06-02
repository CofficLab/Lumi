import Foundation

/// 创建主窗口时传递的初始上下文。
///
/// Route 只用于窗口创建阶段；窗口创建后的运行期状态由 `WindowContainer` 持有。
///
/// 新窗口以全新状态打开。`projectPath` 用于 Dock 拖拽文件夹等场景。
struct LumiWindowRoute: Codable, Hashable, Identifiable {
    var id: UUID
    var projectPath: String?

    init(
        id: UUID = UUID(),
        projectPath: String? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
    }
}
