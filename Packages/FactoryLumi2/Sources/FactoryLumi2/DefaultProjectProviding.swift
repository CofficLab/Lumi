import Combine
import Foundation
import ProviderProject

/// `ProjectProviding` 的内存默认实现。
///
/// 骨架阶段使用：提供最基本的内存项目管理能力（无持久化）。
/// 后续可由具体插件/宿主提供更完整的实现替换。
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
