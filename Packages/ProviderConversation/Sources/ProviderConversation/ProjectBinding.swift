import Foundation

/// 创建对话时如何绑定项目。
///
/// 历史接口用 `projectPath: String?` 同时承载两种意图：`nil` 既可能是
/// 「未指定，沿用当前项目」，也可能是「明确不绑定」。持久化实现会把 `nil`
/// 解释成前者，因此调用方无法创建一条明确无项目的新对话——无项目对话
/// 分叉后会被悄悄挂到当前项目上。
///
/// 这里用枚举把三种意图显式区分开：调用方必须说明自己是「沿用当前」、
/// 「明确不绑定」还是「绑定到某个项目」，语义不再藏在 `nil` 里。
public enum ProjectBinding: Equatable, Sendable {
    /// 沿用创建时刻的当前项目。这是旧 `projectPath: nil` 的语义。
    case inheritCurrent

    /// 明确不绑定任何项目。
    case none

    /// 绑定到指定项目路径。
    case project(String)

    /// 解析成落库的 `projectPath`。
    ///
    /// 空字符串不是合法的项目标识，一律按「未绑定」处理，避免脏数据
    /// 进入持久化层。
    ///
    /// - Parameter currentProjectPath: 调用方视角的当前项目路径，仅
    ///   `.inheritCurrent` 会使用。
    public func resolvedProjectPath(inheriting currentProjectPath: String?) -> String? {
        switch self {
        case .inheritCurrent:
            return nonEmpty(currentProjectPath)
        case .none:
            return nil
        case .project(let path):
            return nonEmpty(path)
        }
    }

    private func nonEmpty(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return path
    }
}
