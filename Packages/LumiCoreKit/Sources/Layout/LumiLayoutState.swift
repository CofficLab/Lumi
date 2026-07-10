import Combine
import CoreGraphics
import Foundation
import os
import SuperLogKit

/// LumiCore 布局状态管理器
/// 负责管理当前布局状态
///
/// 状态变更时会通过 `NotificationCenter` 发出事件，
/// 插件可监听通知进行持久化等响应操作，内核本身不感知插件存在。
///
/// ## 分栏尺寸语义
/// 内核存储的是 **divider 位置**（NSSplitView 的 `setPosition(_:ofDividerAt:)` 接受的值），
/// 而不是 pane 的 width/height。这样选择的原因：
/// 1. divider 位置是 NSSplitView 的原生持久化粒度，无需再做坐标变换；
/// 2. 对窗口 resize、holdingPriority 行为更鲁棒（divider 位置由 split view 自己维护）；
/// 3. pane 的 width/height 可由 `dividerPosition` + `splitView.bounds.size` 推算出来。
@MainActor
public final class LumiLayoutState: ObservableObject, LumiBottomPanelLayoutPresenting, SuperLog {
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = true
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.layout")

    // MARK: - 当前激活视图容器

    @Published public var activeViewContainerID: String? {
        didSet {
            guard activeViewContainerID != oldValue else { return }
            let value = activeViewContainerID
            if Self.verbose {
                Self.logger.info("\(Self.t)activeViewContainerID → \(value ?? "nil")")
            }
            NotificationCenter.postActiveViewContainerIDDidChange(containerID: value)
        }
    }

    // MARK: - 可见性状态

    @Published public var chatSectionVisible: Bool = true {
        didSet {
            guard chatSectionVisible != oldValue else { return }
            let value = chatSectionVisible
            if Self.verbose {
                Self.logger.info("\(Self.t)chatSectionVisible → \(value)")
            }
            NotificationCenter.postChatSectionVisibleDidChange(visible: value)
        }
    }
    @Published public var bottomPanelVisible: Bool = true {
        didSet {
            guard bottomPanelVisible != oldValue else { return }
            let value = bottomPanelVisible
            if Self.verbose {
                Self.logger.info("\(Self.t)bottomPanelVisible → \(value)")
            }
            NotificationCenter.postBottomPanelVisibleDidChange(visible: value)
        }
    }

    // MARK: - 面板状态

    @Published public var activeRailTabID: String = "explorer" {
        didSet {
            guard activeRailTabID != oldValue else { return }
            let value = activeRailTabID
            if Self.verbose {
                Self.logger.info("\(Self.t)activeRailTabID → \(value)")
            }
            NotificationCenter.postActiveRailTabIDDidChange(railTabID: value)
        }
    }
    @Published public var activeBottomTabID: String = "editor-bottom-problems" {
        didSet {
            guard activeBottomTabID != oldValue else { return }
            let value = activeBottomTabID
            if Self.verbose {
                Self.logger.info("\(Self.t)activeBottomTabID → \(value)")
            }
            NotificationCenter.postActiveBottomTabIDDidChange(bottomTabID: value)
        }
    }
    @Published private(set) public var bottomPanelFocusGeneration = 0

    // MARK: - 分栏 divider 位置状态

    /// 各视图容器的 Rail divider 位置（HSplitView 中 divider 0 的 x 坐标 = pane 0 宽度 = Rail 宽度）。
    @Published private var railDividers: [String: CGFloat] = [:]
    /// 各视图容器的聊天区 divider 位置，key 形如 `<viewContainerID>.<layoutSuffix>`。
    @Published private var chatSectionDividers: [String: CGFloat] = [:]
    /// 各视图容器的底部面板 divider 位置（VSplitView 中 divider 0 的 y 坐标 = pane 0 高度 = 内容区高度）。
    /// 注意：这是 pane 0（内容区）的高度，不是 pane 1（底部面板）的高度——它只是 NSSplitView 视角的"divider 在哪"。
    @Published private var bottomPanelDividers: [String: CGFloat] = [:]

    /// 内置默认位置，作为未持久化时的回退值。
    private let defaultRailDivider: CGFloat
    private let defaultChatSectionDivider: CGFloat
    /// 默认底部面板 divider 位置：假设典型窗口高度 600pt，divider 在 400pt 处 → 底部面板约 200pt。
    private let defaultBottomPanelDivider: CGFloat

    // MARK: - 初始化

    /// - Parameters:
    ///   - defaultRailDivider: 未持久化时 Rail divider 的默认位置（= Rail 宽度）。
    ///   - defaultChatSectionDivider: 未持久化时聊天区 divider 的默认位置（= 聊天区宽度）。
    ///   - defaultBottomPanelDivider: 未持久化时底部面板 divider 的默认位置（典型窗口下 = 内容区高度）。
    public init(
        defaultRailDivider: CGFloat = 240,
        defaultChatSectionDivider: CGFloat = 320,
        defaultBottomPanelDivider: CGFloat = 400
    ) {
        self.defaultRailDivider = defaultRailDivider
        self.defaultChatSectionDivider = defaultChatSectionDivider
        self.defaultBottomPanelDivider = defaultBottomPanelDivider
    }

    // MARK: - 公开方法

    /// 激活指定视图容器
    public func activateViewContainer(id: String) {
        activeViewContainerID = id
    }

    /// 清除当前激活的视图容器
    public func clearActiveViewContainer() {
        activeViewContainerID = nil
    }

    // MARK: - 分栏 divider 位置读写

    /// 读取指定视图容器的 Rail divider 位置，未保存时返回 `fallback`。
    public func railDivider(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        railDividers[viewContainerID] ?? fallback ?? defaultRailDivider
    }

    /// 读取已显式保存的 Rail divider 位置，未保存时返回 nil（用于区分"有存储值"与"使用默认值"）。
    public func storedRailDivider(for viewContainerID: String) -> CGFloat? {
        railDividers[viewContainerID]
    }

    /// 设置指定视图容器的 Rail divider 位置，值变化时发出通知（由插件负责持久化）。
    public func setRailDivider(_ position: CGFloat, for viewContainerID: String) {
        let clamped = position
        guard railDividers[viewContainerID] != clamped else { return }
        railDividers[viewContainerID] = clamped
        if Self.verbose {
            Self.logger.info("\(Self.t)railDivider[\(viewContainerID)] → \(clamped)")
        }
        NotificationCenter.postRailDividerDidChange(containerID: viewContainerID, position: clamped)
    }

    /// 内部回填 Rail divider 位置（恢复时使用，不发通知）。
    public func restoreRailDivider(_ position: CGFloat, for viewContainerID: String) {
        railDividers[viewContainerID] = position
    }

    /// 读取指定视图容器 + 布局档位下的聊天区 divider 位置，未保存时返回 `fallback`。
    public func chatSectionDivider(
        for viewContainerID: String,
        layout: LumiChatSectionLayout,
        fallback: CGFloat? = nil
    ) -> CGFloat {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)]
            ?? fallback ?? defaultChatSectionDivider
    }

    /// 读取已显式保存的聊天区 divider 位置，未保存时返回 nil。
    public func storedChatSectionDivider(
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> CGFloat? {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)]
    }

    /// 设置指定视图容器 + 布局档位下的聊天区 divider 位置，值变化时发出通知。
    public func setChatSectionDivider(
        _ position: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        let key = chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)
        guard chatSectionDividers[key] != position else { return }
        chatSectionDividers[key] = position
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionDivider[\(viewContainerID).\(layout.persistenceKeySuffix)] → \(position)")
        }
        NotificationCenter.postChatSectionDividerDidChange(
            containerID: viewContainerID,
            layout: layout.persistenceKeySuffix,
            position: position
        )
    }

    /// 内部回填聊天区 divider 位置（恢复时使用，不发通知）。
    public func restoreChatSectionDivider(
        _ position: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        chatSectionDividers[chatSectionDividerKey(viewContainerID: viewContainerID, layout: layout)] = position
    }

    /// 读取指定视图容器的底部面板 divider 位置（= 内容区高度），未保存时返回 `fallback`。
    public func bottomPanelDivider(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        bottomPanelDividers[viewContainerID] ?? fallback ?? defaultBottomPanelDivider
    }

    /// 读取已显式保存的底部面板 divider 位置，未保存时返回 nil。
    public func storedBottomPanelDivider(for viewContainerID: String) -> CGFloat? {
        bottomPanelDividers[viewContainerID]
    }

    /// 设置指定视图容器的底部面板 divider 位置，值变化时发出通知（由插件负责持久化）。
    public func setBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        guard bottomPanelDividers[viewContainerID] != position else { return }
        bottomPanelDividers[viewContainerID] = position
        if Self.verbose {
            Self.logger.info("\(Self.t)bottomPanelDivider[\(viewContainerID)] → \(position)")
        }
        NotificationCenter.postBottomPanelDividerDidChange(containerID: viewContainerID, position: position)
    }

    /// 内部回填底部面板 divider 位置（恢复时使用，不发通知）。
    public func restoreBottomPanelDivider(_ position: CGFloat, for viewContainerID: String) {
        bottomPanelDividers[viewContainerID] = position
    }

    private func chatSectionDividerKey(
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> String {
        "\(viewContainerID).\(layout.persistenceKeySuffix)"
    }

    // MARK: - LumiBottomPanelLayoutPresenting

    public func presentRailTab(id: String) {
        activeRailTabID = id
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        activeBottomTabID = id
        bottomPanelFocusGeneration += 1
    }
}
