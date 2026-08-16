import Combine
import CoreGraphics
import Foundation

@MainActor
public final class DefaultWorkspaceProviding: WorkspaceProviding {
    @Published public private(set) var containers: [WorkspaceContainer] = []
    @Published public private(set) var activeContainerID: String?
    @Published public private(set) var isRailVisible = true
    @Published public private(set) var isChatVisible = true
    @Published public private(set) var isPanelHeaderVisible = true
    @Published public private(set) var isPanelBodyVisible = true
    @Published public private(set) var isPanelBottomVisible = true

    public let settingsDirectory: URL
    private let fileManager: FileManager
    private var ownersByContainerID: [String: String] = [:]
    private var overridesByContainerID: [String: WorkspaceVisibilityOverrides] = [:]
    private var activeRailTabIDs: [String: String] = [:]
    private var activeBottomTabIDs: [String: String] = [:]
    private var railDividers: [String: CGFloat] = [:]
    private var chatDividers: [String: CGFloat] = [:]
    private var bottomPanelDividers: [String: CGFloat] = [:]
    private var restoredActiveContainerID: String?

    public var currentContainer: WorkspaceContainer? { activeContainerID.flatMap(container(id:)) }

    public init(pluginDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let root = pluginDirectory ?? fileManager.temporaryDirectory
            .appendingPathComponent("Lumi/LayoutKernel", isDirectory: true)
        settingsDirectory = root.appendingPathComponent("settings", isDirectory: true)
        restore()
    }

    public func registerContainer(_ container: WorkspaceContainer, ownerPluginID: String) {
        guard ownersByContainerID[container.id] == nil else { return }
        ownersByContainerID[container.id] = ownerPluginID
        containers.append(container)
        containers.sort { $0.order == $1.order ? $0.id < $1.id : $0.order < $1.order }
        if restoredActiveContainerID == container.id {
            activeContainerID = container.id
            restoredActiveContainerID = nil
            applyContainerVisibility(for: container.id)
        } else if activeContainerID == nil, let first = containers.first {
            activateContainer(id: first.id)
        }
    }

    public func unregisterContainers(ownerPluginID: String) {
        let ids = Set(ownersByContainerID.compactMap { $0.value == ownerPluginID ? $0.key : nil })
        guard !ids.isEmpty else { return }
        ownersByContainerID = ownersByContainerID.filter { !ids.contains($0.key) }
        containers.removeAll { ids.contains($0.id) }
        if let activeContainerID, ids.contains(activeContainerID) {
            self.activeContainerID = nil
            if let first = containers.first { activateContainer(id: first.id) }
        }
        persistBestEffort()
    }

    public func container(id: String) -> WorkspaceContainer? { containers.first { $0.id == id } }

    public func activateContainer(id: String) {
        guard container(id: id) != nil else { return }
        activeContainerID = id
        applyContainerVisibility(for: id)
        persistBestEffort()
    }

    public func applyContainerVisibility(for id: String) {
        guard let item = container(id: id) else { return }
        let value = overridesByContainerID[id]
        isRailVisible = item.railVisibility.resolve(userOverride: value?.rail)
        isChatVisible = item.chatVisibility.resolve(userOverride: value?.chat)
        isPanelHeaderVisible = item.panelHeaderVisibility.resolve(userOverride: value?.panelHeader)
        isPanelBodyVisible = item.panelBodyVisibility.resolve(userOverride: value?.panelBody)
        isPanelBottomVisible = item.panelBottomVisibility.resolve(userOverride: value?.panelBottom)
    }

    public func setRailVisible(_ visible: Bool) { updateOverride(\.rail, value: visible) { self.isRailVisible = $0 } }
    public func setChatVisible(_ visible: Bool) { updateOverride(\.chat, value: visible) { self.isChatVisible = $0 } }
    public func setPanelHeaderVisible(_ visible: Bool) { updateOverride(\.panelHeader, value: visible) { self.isPanelHeaderVisible = $0 } }
    public func setPanelBodyVisible(_ visible: Bool) { updateOverride(\.panelBody, value: visible) { self.isPanelBodyVisible = $0 } }
    public func setPanelBottomVisible(_ visible: Bool) { updateOverride(\.panelBottom, value: visible) { self.isPanelBottomVisible = $0 } }

    public func activeRailTabID(for containerID: String) -> String? { activeRailTabIDs[containerID] }
    public func presentRailTab(id: String, for containerID: String) { activeRailTabIDs[containerID] = id; persistBestEffort() }
    public func activeBottomTabID(for containerID: String) -> String? { activeBottomTabIDs[containerID] }
    public func presentBottomTab(id: String, for containerID: String) { activeBottomTabIDs[containerID] = id; persistBestEffort() }
    public func railDivider(for containerID: String, fallback: CGFloat) -> CGFloat { railDividers[containerID] ?? fallback }
    public func setRailDivider(_ width: CGFloat, for containerID: String) { railDividers[containerID] = width; persistBestEffort() }
    public func chatDivider(for containerID: String, layout: WorkspaceChatLayout, fallback: CGFloat) -> CGFloat {
        chatDividers[chatKey(containerID, layout)] ?? fallback
    }
    public func setChatDivider(_ width: CGFloat, for containerID: String, layout: WorkspaceChatLayout) {
        chatDividers[chatKey(containerID, layout)] = width; persistBestEffort()
    }
    public func bottomPanelDivider(for containerID: String, fallback: CGFloat) -> CGFloat { bottomPanelDividers[containerID] ?? fallback }
    public func setBottomPanelDivider(_ height: CGFloat, for containerID: String) { bottomPanelDividers[containerID] = height; persistBestEffort() }
    public func visibilityOverrides(for containerID: String) -> WorkspaceVisibilityOverrides? { overridesByContainerID[containerID] }

    public func snapshot() -> WorkspaceLayoutSnapshot {
        WorkspaceLayoutSnapshot(activeViewContainerID: activeContainerID ?? restoredActiveContainerID,
            chatSectionVisible: isChatVisible, railVisible: isRailVisible,
            panelBottomVisible: isPanelBottomVisible, activeRailTabIDs: activeRailTabIDs,
            activeBottomTabIDs: activeBottomTabIDs, visibilityOverrides: overridesByContainerID,
            railDividers: railDividers, chatSectionDividers: chatDividers,
            bottomPanelDividers: bottomPanelDividers)
    }

    public func restore() {
        guard let data = try? Data(contentsOf: layoutFileURL),
              let state = try? JSONDecoder().decode(WorkspaceLayoutSnapshot.self, from: data) else { return }
        restoredActiveContainerID = state.activeViewContainerID
        isChatVisible = state.chatSectionVisible; isRailVisible = state.railVisible
        isPanelBottomVisible = state.panelBottomVisible; activeRailTabIDs = state.activeRailTabIDs
        activeBottomTabIDs = state.activeBottomTabIDs; overridesByContainerID = state.visibilityOverrides
        railDividers = state.railDividers; chatDividers = state.chatSectionDividers
        bottomPanelDividers = state.bottomPanelDividers
    }

    public func save() throws {
        try fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot()).write(to: layoutFileURL, options: .atomic)
    }

    private func updateOverride(_ keyPath: WritableKeyPath<WorkspaceVisibilityOverrides, Bool?>,
                                value: Bool, assign: (Bool) -> Void) {
        guard let id = activeContainerID, let item = container(id: id) else {
            assign(value); persistBestEffort(); return
        }
        let visibility = policy(for: keyPath, in: item)
        guard visibility.allowsUserOverride else { assign(visibility.defaultIsVisible); return }
        overridesByContainerID[id, default: .init()][keyPath: keyPath] = value
        assign(value); persistBestEffort()
    }

    private func policy(for keyPath: WritableKeyPath<WorkspaceVisibilityOverrides, Bool?>,
                        in item: WorkspaceContainer) -> WorkspaceRegionVisibility {
        switch keyPath {
        case \.rail: item.railVisibility
        case \.chat: item.chatVisibility
        case \.panelHeader: item.panelHeaderVisibility
        case \.panelBody: item.panelBodyVisibility
        case \.panelBottom: item.panelBottomVisibility
        default: .unsupported
        }
    }

    private func chatKey(_ id: String, _ layout: WorkspaceChatLayout) -> String { "\(id).\(layout.rawValue)" }
    private var layoutFileURL: URL { settingsDirectory.appendingPathComponent("layout-info.json") }
    private func persistBestEffort() { try? save() }
}
