import Foundation

/// 项目上下文相关的一次性意图（由 VM 持有，RootView `onChange` 触发 Handler）。
enum ProjectContextRequest: Equatable {
    case switchProject(path: String)
    case clearProject
}
