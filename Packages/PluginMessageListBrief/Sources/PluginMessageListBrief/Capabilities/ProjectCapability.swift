import Foundation
import ProviderProject

/// 消息列表所需的最小项目能力。
@MainActor
protocol MessageListProjectCapability: AnyObject {
    var currentProject: ProjectInfo? { get }
    var projects: [ProjectInfo] { get }
    func openProject(at path: String) async throws
}

@MainActor
final class MessageListProjectCapabilityAdapter: MessageListProjectCapability {
    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
    }

    var currentProject: ProjectInfo? { project.currentProject }
    var projects: [ProjectInfo] { project.projects }

    func openProject(at path: String) async throws {
        try await project.openProject(at: path)
    }
}
