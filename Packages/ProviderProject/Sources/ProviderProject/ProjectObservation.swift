import Foundation

/// 项目状态的语义变更事件。
@MainActor
public enum ProjectProvidingEvent: Sendable {
    /// 项目列表发生变化。
    case projectsChanged([ProjectInfo])
    /// 当前项目发生变化；`nil` 表示当前没有打开项目。
    case currentProjectChanged(ProjectInfo?)
    /// 当前项目的打开文件列表发生变化。
    case openFilesChanged([URL])
    /// 当前选中文件发生变化；`nil` 表示没有选中文件。
    case currentFileChanged(URL?)
}

/// 项目状态观察句柄。
@MainActor
public protocol ProjectProvidingObserverHandle: AnyObject {
    /// 停止接收后续项目变更通知。重复调用无副作用。
    func cancel()
}

/// 不需要语义事件实现的轻量 `ProjectProviding` 替身兼容句柄。
@MainActor
public final class NoopProjectProvidingObserverHandle: ProjectProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}
