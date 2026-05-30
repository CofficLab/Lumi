import Foundation
import SwiftUI

@MainActor
public final class WindowLayoutVM: ObservableObject {
    @Published public var bottomPanelVisible: Bool
    @Published public var contentPanelVisible: Bool
    @Published public var editorVisible: Bool
    @Published public var railVisible: Bool
    @Published public var rightSidebarVisible: Bool
    @Published public var activeViewContainerIcon: String?
    @Published public var selectedAgentSidebarTabId: String
    @Published public var selectedAgentDetailId: String
    @Published public var layoutRatios: [String: Double]

    public init(
        bottomPanelVisible: Bool = true,
        contentPanelVisible: Bool = true,
        editorVisible: Bool = true,
        railVisible: Bool = true,
        rightSidebarVisible: Bool = true,
        activeViewContainerIcon: String? = nil,
        selectedAgentSidebarTabId: String = "",
        selectedAgentDetailId: String = "",
        layoutRatios: [String: Double] = [:]
    ) {
        self.bottomPanelVisible = bottomPanelVisible
        self.contentPanelVisible = contentPanelVisible
        self.editorVisible = editorVisible
        self.railVisible = railVisible
        self.rightSidebarVisible = rightSidebarVisible
        self.activeViewContainerIcon = activeViewContainerIcon
        self.selectedAgentSidebarTabId = selectedAgentSidebarTabId
        self.selectedAgentDetailId = selectedAgentDetailId
        self.layoutRatios = layoutRatios
    }

    public func restoreFromPlugin(activeViewContainerIcon: String?) {
        self.activeViewContainerIcon = activeViewContainerIcon
    }

    public func restoreFromPlugin(tabId: String) {
        selectedAgentSidebarTabId = tabId
    }

    public func selectAgentSidebarTab(_ tabId: String, reason: String) {
        selectedAgentSidebarTabId = tabId
    }

    public func restoreFromPlugin(detailId: String) {
        selectedAgentDetailId = detailId
    }

    public func restoreFromPlugin(ratios: [String: Double]) {
        layoutRatios = ratios
    }

    public func restoreFromPlugin(bottomPanelVisible: Bool) {
        self.bottomPanelVisible = bottomPanelVisible
    }

    public func restoreFromPlugin(contentPanelVisible: Bool) {
        self.contentPanelVisible = contentPanelVisible
    }

    public func restoreFromPlugin(editorVisible: Bool) {
        self.editorVisible = editorVisible
    }

    public func restoreFromPlugin(railVisible: Bool) {
        self.railVisible = railVisible
    }

    public func restoreFromPlugin(rightSidebarVisible: Bool) {
        self.rightSidebarVisible = rightSidebarVisible
    }

    public func update(
        bottomPanelVisible: Bool,
        contentPanelVisible: Bool,
        editorVisible: Bool,
        railVisible: Bool,
        rightSidebarVisible: Bool,
        activeViewContainerIcon: String?,
        selectedAgentSidebarTabId: String,
        selectedAgentDetailId: String,
        layoutRatios: [String: Double]
    ) {
        self.bottomPanelVisible = bottomPanelVisible
        self.contentPanelVisible = contentPanelVisible
        self.editorVisible = editorVisible
        self.railVisible = railVisible
        self.rightSidebarVisible = rightSidebarVisible
        self.activeViewContainerIcon = activeViewContainerIcon
        self.selectedAgentSidebarTabId = selectedAgentSidebarTabId
        self.selectedAgentDetailId = selectedAgentDetailId
        self.layoutRatios = layoutRatios
    }
}
