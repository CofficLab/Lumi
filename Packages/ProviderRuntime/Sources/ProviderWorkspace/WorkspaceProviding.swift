import Combine
import CoreGraphics
import Foundation

@MainActor
public protocol WorkspaceProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var settingsDirectory: URL { get }
    var containers: [WorkspaceContainer] { get }
    var isRailVisible: Bool { get }
    var isChatVisible: Bool { get }
    var isPanelHeaderVisible: Bool { get }
    var isPanelBodyVisible: Bool { get }
    var isPanelBottomVisible: Bool { get }
    var activeContainerID: String? { get }
    var currentContainer: WorkspaceContainer? { get }
    func registerContainer(_ container: WorkspaceContainer, ownerPluginID: String)
    func unregisterContainers(ownerPluginID: String)
    func container(id: String) -> WorkspaceContainer?
    func setRailVisible(_ visible: Bool)
    func setChatVisible(_ visible: Bool)
    func setPanelHeaderVisible(_ visible: Bool)
    func setPanelBodyVisible(_ visible: Bool)
    func setPanelBottomVisible(_ visible: Bool)
    func activateContainer(id: String)
    func applyContainerVisibility(for id: String)
    func activeRailTabID(for containerID: String) -> String?
    func presentRailTab(id: String, for containerID: String)
    func activeBottomTabID(for containerID: String) -> String?
    func presentBottomTab(id: String, for containerID: String)
    func railDivider(for containerID: String, fallback: CGFloat) -> CGFloat
    func setRailDivider(_ width: CGFloat, for containerID: String)
    func chatDivider(for containerID: String, layout: WorkspaceChatLayout, fallback: CGFloat) -> CGFloat
    func setChatDivider(_ width: CGFloat, for containerID: String, layout: WorkspaceChatLayout)
    func bottomPanelDivider(for containerID: String, fallback: CGFloat) -> CGFloat
    func setBottomPanelDivider(_ height: CGFloat, for containerID: String)
    func visibilityOverrides(for containerID: String) -> WorkspaceVisibilityOverrides?
    func snapshot() -> WorkspaceLayoutSnapshot
    func restore()
    func save() throws
}
