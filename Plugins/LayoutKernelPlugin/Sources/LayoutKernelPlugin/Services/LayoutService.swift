import Combine
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

    /// 订阅 `layoutState.objectWillChange`,转发到本服务。
    ///
    /// `activeRailTabID`、`bottomPanelVisible` 等运行时状态都存放在 `LayoutState` 的
    /// `@Published` 属性里。Kernel 只订阅本服务(通过 `LayoutProviding`)的
    /// `objectWillChange`,若不在此转发,任何 `LayoutState` 的变更都无法触发
    /// `@ObservedObject kernel` 的视图重绘——表现为 Rail 标签栏高亮不随点击切换等故障。
    private var layoutStateSubscription: AnyCancellable?

    public init(initialState: LayoutStateInfo = LayoutStateInfo()) {
        self.state = initialState
        self.layoutState = LayoutState()

        // 把 LayoutState 的变更重新发布到 LayoutService,使经 LayoutProviding
        // 订阅本服务的消费者(kernel 及其视图)能收到通知。
        self.layoutStateSubscription = layoutState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }

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
    public var isPanelVisible: Bool { layoutState.isPanelVisible }

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) { layoutState.setRailVisible(visible) }
    public func setChatVisible(_ visible: Bool) { layoutState.setChatVisible(visible) }
    public func setContentVisible(_ visible: Bool) { layoutState.setContentVisible(visible) }
    public func setPanelVisible(_ visible: Bool) { layoutState.setPanelVisible(visible) }

    public func activateContainer(id: String) { layoutState.activateContainer(id: id) }
    public func applyVisibility(rail: Bool?, chat: Bool?, content: Bool?, panel: Bool?) {
        layoutState.applyVisibility(rail: rail, chat: chat, content: content, panel: panel)
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
