import Foundation

/// 记忆作用域
///
/// 定义记忆存储的全局或项目级位置。
public enum MemoryScope: Equatable, Sendable {
    /// 全局记忆（跨项目通用）
    case global
    /// 项目级记忆（特定于某个项目路径）
    case project(String)

    // MARK: - Equatable

    public static func == (lhs: MemoryScope, rhs: MemoryScope) -> Bool {
        switch (lhs, rhs) {
        case (.global, .global):
            return true
        case let (.project(lhsPath), .project(rhsPath)):
            return lhsPath == rhsPath
        default:
            return false
        }
    }
}
