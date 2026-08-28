import Combine
import Foundation
import KitSuperLog
import os

/// `ProjectProviding` 的内存默认实现。
///
/// 提供最基本的内存项目管理能力（无持久化）：
/// 打开项目、关闭项目、维护内存中的项目列表。
/// 需要持久化等完整能力的宿主应提供自己的实现替换。
@MainActor
public final class DefaultProjectProvider: ProjectProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-project", category: "Project")
    public nonisolated static let emoji = "📁"

    @Published public var currentProject: ProjectInfo?
    @Published public var projects: [ProjectInfo] = []
    @Published public var openFileURLs: [URL] = []
    @Published public var currentFileURL: URL?

    public init() {
        Self.logger.warning("\(Self.t)DefaultProjectProviding is an incomplete default implementation")
    }

    public func openProject(at path: String) async throws {
        Self.logger.warning("\(Self.t)DefaultProjectProviding.openProject uses in-memory state only; persistent project support is incomplete")
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
        Self.logger.warning("\(Self.t)DefaultProjectProviding.closeProject uses in-memory state only; complete project cleanup is not implemented")
        currentProject = nil
    }

    public func refreshProjects() async throws {
        Self.logger.warning("\(Self.t)DefaultProjectProviding.refreshProjects is incomplete; no persistent project source is available")
        // 骨架阶段：无持久化来源，保持当前内存列表。
    }

    public func updateCurrentFile(_ fileURL: URL?) {
        Self.logger.warning("\(Self.t)DefaultProjectProviding.updateCurrentFile is incomplete; open-file state is not persisted")
    }

    public func updateOpenFiles(_ fileURLs: [URL]) {
        Self.logger.warning("\(Self.t)DefaultProjectProviding.updateOpenFiles is incomplete; open-file state is not persisted")
    }

    public func closeFile(_ fileURL: URL) {
        Self.logger.warning("\(Self.t)DefaultProjectProviding.closeFile is incomplete; open-file state is not persisted")
    }

    public func synchronizeProjects(_ projects: [ProjectInfo]) {
        Self.logger.warning("\(Self.t)DefaultProjectProviding.synchronizeProjects is incomplete; project synchronization is not persisted")
    }
}
