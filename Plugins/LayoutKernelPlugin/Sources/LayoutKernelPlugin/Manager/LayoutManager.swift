import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 布局服务实现
///
/// 持久化由外层插件负责，详见 `LayoutStore`。内核仅持有运行时状态 `layoutState`。
@MainActor
public final class LayoutManager: LayoutProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout.service")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = true

    /// 布局状态（用于视图绑定和运行时状态）
    public let layoutState: LayoutState

    /// 订阅 `layoutState.objectWillChange`,转发到本服务。
    ///
    /// `activeRailTabID`、`bottomPanelVisible` 等运行时状态都存放在 `LayoutState` 的
    /// `@Published` 属性里。Kernel 只订阅本服务(通过 `LayoutProviding`)的
    /// `objectWillChange`,若不在此转发,任何 `LayoutState` 的变更都无法触发
    /// `@ObservedObject kernel` 的视图重绘——表现为 Rail 标签栏高亮不随点击切换等故障。
    private var layoutStateSubscription: AnyCancellable?

    public init() {
        self.layoutState = LayoutState()

        // 把 LayoutState 的变更重新发布到 LayoutManager,使经 LayoutProviding
        // 订阅本服务的消费者(kernel 及其视图)能收到通知。
        self.layoutStateSubscription = layoutState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }

        if Self.verbose {
            Self.logger.info("\(Self.t)LayoutManager initialized")
        }
    }

    // MARK: - Workspace Visibility

    public var isRailVisible: Bool { layoutState.isRailVisible }
    public var isChatVisible: Bool { layoutState.isChatVisible }
    public var isContentVisible: Bool { layoutState.isContentVisible }
    public var isPanelVisible: Bool { layoutState.isPanelVisible }
    public var isPanelBottomVisible: Bool { layoutState.isPanelBottomVisible }

    // MARK: - Workspace Commands

    public func setRailVisible(_ visible: Bool) { layoutState.setRailVisible(visible) }
    public func setChatVisible(_ visible: Bool) { layoutState.setChatVisible(visible) }
    public func setContentVisible(_ visible: Bool) { layoutState.setContentVisible(visible) }
    public func setPanelVisible(_ visible: Bool) { layoutState.setPanelVisible(visible) }
    public func setPanelBottomVisible(_ visible: Bool) { layoutState.setPanelBottomVisible(visible) }

    public func activateContainer(id: String) {
        let container = self.layoutState.viewContainer(id: id)
        let containerBottomVisible = container?.isPanelBottomVisible
        if Self.verbose {
            Self.logger.info("\(Self.t)activateContainer(id: \(id), container.isPanelBottomVisible: \(containerBottomVisible.map { String($0) } ?? "nil"))")
        }
        self.layoutState.activateContainer(id: id)
        let bottomVisible = self.layoutState.isPanelBottomVisible
        if Self.verbose {
            Self.logger.info("\(Self.t)activateContainer done, isPanelBottomVisible = \(bottomVisible)")
        }
    }
    public func applyVisibility(rail: Bool?, chat: Bool?, content: Bool?, panel: Bool?) {
        if Self.verbose {
            Self.logger.info("\(Self.t)applyVisibility(rail: \(rail.map { String($0) } ?? "-"), chat: \(chat.map { String($0) } ?? "-"), content: \(content.map { String($0) } ?? "-"), panel: \(panel.map { String($0) } ?? "-"))")
        }
        layoutState.applyVisibility(rail: rail, chat: chat, content: content, panel: panel)
    }
    public func addContainerObserver(_ observer: @escaping (String) -> Void) {
        layoutState.addContainerObserver(observer)
    }

    // MARK: - View Containers

    public var allViewContainers: [ViewContainerItem] { layoutState.allViewContainers }
    public func viewContainer(id: String) -> ViewContainerItem? { layoutState.viewContainer(id: id) }
    public func registerViewContainer(_ container: ViewContainerItem) { layoutState.registerViewContainer(container) }
    public func unregisterViewContainer(id: String) { layoutState.unregisterViewContainer(id: id) }

    // MARK: - Container

    public var activeViewContainerID: String? { layoutState.activeViewContainerID }

    // MARK: - Section Info

    public var activeSectionID: String { layoutState.activeSectionID }
    public var activeSectionTitle: String { layoutState.activeSectionTitle }

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
