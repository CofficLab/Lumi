import Combine
import Foundation

/// `ProjectProviding` 的内存默认实现。
///
/// 提供最基本的内存项目管理能力（无持久化）：
/// 打开项目、关闭项目、维护内存中的项目列表。
/// 需要持久化等完整能力的宿主应提供自己的实现替换。
@MainActor
public final class DefaultProjectProviding: ProjectProviding {
    @Published public var currentProject: ProjectInfo?
    @Published public var projects: [ProjectInfo] = []

    public init() {}

    public func openProject(at path: String) async throws {
        let info = ProjectInfo(
            name: (path as NSString).lastPathComponent,
            path: path
        )
        currentProject = info
        if !projects.contains(where: { $0.path == path }) {
            projects.append(info)
        }
    }

    public func closeProject() async {
        currentProject = nil
    }

    public func refreshProjects() async throws {
        // 骨架阶段：无持久化来源，保持当前内存列表。
    }
}
