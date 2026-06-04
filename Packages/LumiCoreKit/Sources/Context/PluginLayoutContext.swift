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

    /// 首次回退：当磁盘没有保存过 activeViewContainerIcon 时，
    /// 由 app 层设置此闭包返回默认图标（第一个 view container 的 icon）。
    /// 布局状态提供方在恢复阶段调用。
    public var defaultIconProvider: (() -> String?)?

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

    public func restorePersisted(activeViewContainerIcon: String?) {
        guard self.activeViewContainerIcon != activeViewContainerIcon else { return }
        self.activeViewContainerIcon = activeViewContainerIcon
    }

    public func restorePersisted(tabId: String) {
        guard selectedAgentSidebarTabId != tabId else { return }
        selectedAgentSidebarTabId = tabId
    }

    public func selectAgentSidebarTab(_ tabId: String, reason: String) {
        guard selectedAgentSidebarTabId != tabId else { return }
        selectedAgentSidebarTabId = tabId
    }

    public func restorePersisted(detailId: String) {
        guard selectedAgentDetailId != detailId else { return }
        selectedAgentDetailId = detailId
    }

    public func restorePersisted(ratios: [String: Double]) {
        guard layoutRatios != ratios else { return }
        layoutRatios = ratios
    }

    public func restorePersisted(bottomPanelVisible: Bool) {
        guard self.bottomPanelVisible != bottomPanelVisible else { return }
        self.bottomPanelVisible = bottomPanelVisible
    }

    public func restorePersisted(contentPanelVisible: Bool) {
        guard self.contentPanelVisible != contentPanelVisible else { return }
        self.contentPanelVisible = contentPanelVisible
    }

    public func restorePersisted(editorVisible: Bool) {
        guard self.editorVisible != editorVisible else { return }
        self.editorVisible = editorVisible
    }

    public func restorePersisted(railVisible: Bool) {
        guard self.railVisible != railVisible else { return }
        self.railVisible = railVisible
    }

    public func restorePersisted(rightSidebarVisible: Bool) {
        guard self.rightSidebarVisible != rightSidebarVisible else { return }
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
        guard self.bottomPanelVisible != bottomPanelVisible ||
            self.contentPanelVisible != contentPanelVisible ||
            self.editorVisible != editorVisible ||
            self.railVisible != railVisible ||
            self.rightSidebarVisible != rightSidebarVisible ||
            self.activeViewContainerIcon != activeViewContainerIcon ||
            self.selectedAgentSidebarTabId != selectedAgentSidebarTabId ||
            self.selectedAgentDetailId != selectedAgentDetailId ||
            self.layoutRatios != layoutRatios
        else { return }

        if self.bottomPanelVisible != bottomPanelVisible {
            self.bottomPanelVisible = bottomPanelVisible
        }
        if self.contentPanelVisible != contentPanelVisible {
            self.contentPanelVisible = contentPanelVisible
        }
        if self.editorVisible != editorVisible {
            self.editorVisible = editorVisible
        }
        if self.railVisible != railVisible {
            self.railVisible = railVisible
        }
        if self.rightSidebarVisible != rightSidebarVisible {
            self.rightSidebarVisible = rightSidebarVisible
        }
        if self.activeViewContainerIcon != activeViewContainerIcon {
            self.activeViewContainerIcon = activeViewContainerIcon
        }
        if self.selectedAgentSidebarTabId != selectedAgentSidebarTabId {
            self.selectedAgentSidebarTabId = selectedAgentSidebarTabId
        }
        if self.selectedAgentDetailId != selectedAgentDetailId {
            self.selectedAgentDetailId = selectedAgentDetailId
        }
        if self.layoutRatios != layoutRatios {
            self.layoutRatios = layoutRatios
        }
    }
}
