import Foundation
import LumiKernel
import os
import SuperLogKit

/// 布局服务实现
@MainActor
public final class LayoutService: LayoutProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout.service")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = true

    /// 布局状态（用于持久化）
    @Published public var state: LayoutStateInfo

    /// 原始布局状态（用于视图绑定）
    public let layoutState: LayoutState

    public init(initialState: LayoutStateInfo = LayoutStateInfo()) {
        self.state = initialState
        self.layoutState = LayoutState()

        if Self.verbose {
            Self.logger.info("\(Self.t)LayoutService initialized")
        }
    }

    public func updateLayout(_ update: (inout LayoutStateInfo) -> Void) {
        if Self.verbose {
            Self.logger.info("\(Self.t)updateLayout called")
        }
        update(&state)
        if Self.verbose {
            Self.logger.info("\(Self.t)updateLayout completed")
        }
    }

    // MARK: - Workspace Visibility

    public var isRailVisible: Bool { layoutState.isRailVisible }
    public var isChatVisible: Bool { layoutState.isChatVisible }
    public var isContentVisible: Bool { layoutState.isContentVisible }
    public var isActivityBarVisible: Bool { layoutState.isActivityBarVisible }
    public var isPanelVisible: Bool { layoutState.isPanelVisible }

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) { layoutState.setRailVisible(visible) }
    public func setChatVisible(_ visible: Bool) { layoutState.setChatVisible(visible) }
    public func setContentVisible(_ visible: Bool) { layoutState.setContentVisible(visible) }
    public func setActivityBarVisible(_ visible: Bool) { layoutState.setActivityBarVisible(visible) }
    public func setPanelVisible(_ visible: Bool) { layoutState.setPanelVisible(visible) }

    public func activateContainer(id: String) { layoutState.activateContainer(id: id) }
    public func applyVisibility(rail: Bool?, chat: Bool?, content: Bool?, activityBar: Bool?, panel: Bool?) {
        layoutState.applyVisibility(rail: rail, chat: chat, content: content, activityBar: activityBar, panel: panel)
    }
    public func addContainerObserver(_ observer: @escaping (String) -> Void) {
        layoutState.addContainerObserver(observer)
    }

    // MARK: - Container

    public var activeViewContainerID: String? { layoutState.activeViewContainerID }

    // MARK: - Rail Tabs

    public var activeRailTabID: String { layoutState.activeRailTabID }
    public func presentRailTab(id: String) { layoutState.presentRailTab(id: id) }

    // MARK: - Bottom Panel

    public var bottomPanelVisible: Bool { layoutState.bottomPanelVisible }
    public func presentBottomTab(id: String, viewContainerID: String) {
        layoutState.presentBottomTab(id: id, viewContainerID: viewContainerID)
    }

    // MARK: - Dividers

    public func railDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat {
        layoutState.railDivider(for: viewContainerID, fallback: fallback)
    }
    public func setRailDivider(_ position: CGFloat, for viewContainerID: String) {
        layoutState.setRailDivider(position, for: viewContainerID)
    }

    public func chatSectionDivider(for viewContainerID: String, layout: LumiChatSectionLayout, fallback: CGFloat?) -> CGFloat {
        layoutState.chatSectionDivider(for: viewContainerID, layout: layout, fallback: fallback)
    }
    public func setChatSectionDivider(_ position: CGFloat, for viewContainerID: String, layout: LumiChatSectionLayout) {
        layoutState.setChatSectionDivider(position, for: viewContainerID, layout: layout)
    }

    public func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat?) -> CGFloat {
        layoutState.bottomPanelDivider(for: viewContainerID, fallback: fallback)
    }
    public func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        layoutState.setBottomPanelDivider(position, for: viewContainerID)
    }
}
