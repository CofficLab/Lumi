import Foundation

@MainActor
public protocol WorkspaceProviding: AnyObject {
    var isRailVisible: Bool { get }
    var isChatVisible: Bool { get }
    var activeContainerID: String? { get }
    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func activateContainer(id: String)
}
@MainActor
public final class DefaultWorkspaceProviding: WorkspaceProviding {
    public private(set) var isRailVisible = true
    public private(set) var isChatVisible = true
    public private(set) var activeContainerID: String?
    public init() {}
    public func setRailVisible(_ visible: Bool) { isRailVisible = visible }
    public func setChatVisible(_ visible: Bool) { isChatVisible = visible }
    public func activateContainer(id: String) { activeContainerID = id }
}
