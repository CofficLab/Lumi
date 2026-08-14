import Foundation

/// 思维导图存储作用域：APP 内（应用数据目录）vs 项目内（当前项目 `.lumi/mind-map` 目录）。
public enum MindMapScope: String, CaseIterable, Sendable {
    case project
    case app

    /// LLM 工具参数使用的字符串名。
    var rawName: String { rawValue }

    /// UI 显示名。
    func displayName() -> String {
        switch self {
        case .project: MindMapLocalization.string("In Project", "项目内")
        case .app: MindMapLocalization.string("In App", "应用内")
        }
    }
}
