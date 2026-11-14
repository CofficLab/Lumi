import ProviderProject

/// 消息列表所需的最小项目能力。
@MainActor
public protocol MessageListProjectCapability: AnyObject {
    var currentProject: ProjectInfo? { get }
    var projects: [ProjectInfo] { get }
    func openProject(at path: String, reason: ProjectChangeReason) async throws
}

@MainActor
public final class MessageListProjectCapabilityAdapter: MessageListProjectCapability {
    private let project: any ProjectProviding
    public init(project: any ProjectProviding) { self.project = project }
    public var currentProject: ProjectInfo? { project.currentProject }
    public var projects: [ProjectInfo] { project.projects }
    public func openProject(at path: String, reason: ProjectChangeReason) async throws {
        try await project.openProject(at: path, reason: reason)
    }
}