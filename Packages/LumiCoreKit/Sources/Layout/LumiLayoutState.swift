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
@MainActor
public final class LumiLayoutState: ObservableObject, LumiBottomPanelLayoutPresenting, SuperLog {
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = false
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

    // MARK: - 分栏尺寸状态

    /// 各视图容器的侧边栏 Rail 宽度（按 `Layout.Width.<id>.Rail` 的 id 维度存储）。
    @Published private var railWidths: [String: CGFloat] = [:]
    /// 各视图容器的聊天区宽度，key 形如 `<viewContainerID>.<layoutSuffix>`。
    @Published private var chatSectionWidths: [String: CGFloat] = [:]
    /// 各视图容器的底部面板高度（按 `Layout.Height.<id>.BottomPanel` 的 id 维度存储）。
    @Published private var bottomPanelHeights: [String: CGFloat] = [:]

    /// 内置默认尺寸，作为未持久化时的回退值。
    private let defaultRailWidth: CGFloat
    private let defaultChatSectionWidth: CGFloat
    private let defaultBottomPanelHeight: CGFloat

    // MARK: - 初始化

    /// - Parameters:
    ///   - defaultRailWidth: 未持久化时使用的 Rail 默认宽度。
    ///   - defaultChatSectionWidth: 未持久化时使用的聊天区默认宽度。
    ///   - defaultBottomPanelHeight: 未持久化时使用的底部面板默认高度。
    public init(
        defaultRailWidth: CGFloat = 240,
        defaultChatSectionWidth: CGFloat = 320,
        defaultBottomPanelHeight: CGFloat = 200
    ) {
        self.defaultRailWidth = defaultRailWidth
        self.defaultChatSectionWidth = defaultChatSectionWidth
        self.defaultBottomPanelHeight = defaultBottomPanelHeight
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

    // MARK: - 分栏尺寸读写

    /// 读取指定视图容器的 Rail 宽度，未保存时返回 `fallback`。
    public func railWidth(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        railWidths[viewContainerID] ?? fallback ?? defaultRailWidth
    }

    /// 读取已显式保存的 Rail 宽度，未保存时返回 nil（用于区分"有存储值"与"使用默认值"）。
    public func storedRailWidth(for viewContainerID: String) -> CGFloat? {
        railWidths[viewContainerID]
    }

    /// 设置指定视图容器的 Rail 宽度，值变化时发出通知（由插件负责持久化）。
    public func setRailWidth(_ width: CGFloat, for viewContainerID: String) {
        let clamped = width
        guard railWidths[viewContainerID] != clamped else { return }
        railWidths[viewContainerID] = clamped
        if Self.verbose {
            Self.logger.info("\(Self.t)railWidth[\(viewContainerID)] → \(clamped)")
        }
        NotificationCenter.postRailWidthDidChange(containerID: viewContainerID, width: clamped)
    }

    /// 内部回填 Rail 宽度（恢复时使用，不发通知）。
    public func restoreRailWidth(_ width: CGFloat, for viewContainerID: String) {
        railWidths[viewContainerID] = width
    }

    /// 读取指定视图容器 + 布局档位下的聊天区宽度，未保存时返回 `fallback`。
    public func chatSectionWidth(
        for viewContainerID: String,
        layout: LumiChatSectionLayout,
        fallback: CGFloat? = nil
    ) -> CGFloat {
        chatSectionWidths[chatSectionWidthKey(viewContainerID: viewContainerID, layout: layout)]
            ?? fallback ?? defaultChatSectionWidth
    }

    /// 读取已显式保存的聊天区宽度，未保存时返回 nil。
    public func storedChatSectionWidth(
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> CGFloat? {
        chatSectionWidths[chatSectionWidthKey(viewContainerID: viewContainerID, layout: layout)]
    }

    /// 设置指定视图容器 + 布局档位下的聊天区宽度，值变化时发出通知。
    public func setChatSectionWidth(
        _ width: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        let key = chatSectionWidthKey(viewContainerID: viewContainerID, layout: layout)
        guard chatSectionWidths[key] != width else { return }
        chatSectionWidths[key] = width
        if Self.verbose {
            Self.logger.info("\(Self.t)chatSectionWidth[\(viewContainerID).\(layout.persistenceKeySuffix)] → \(width)")
        }
        NotificationCenter.postChatSectionWidthDidChange(
            containerID: viewContainerID,
            layout: layout.persistenceKeySuffix,
            width: width
        )
    }

    /// 内部回填聊天区宽度（恢复时使用，不发通知）。
    public func restoreChatSectionWidth(
        _ width: CGFloat,
        for viewContainerID: String,
        layout: LumiChatSectionLayout
    ) {
        chatSectionWidths[chatSectionWidthKey(viewContainerID: viewContainerID, layout: layout)] = width
    }

    /// 读取指定视图容器的底部面板高度，未保存时返回 `fallback`。
    public func bottomPanelHeight(for viewContainerID: String, fallback: CGFloat? = nil) -> CGFloat {
        bottomPanelHeights[viewContainerID] ?? fallback ?? defaultBottomPanelHeight
    }

    /// 读取已显式保存的底部面板高度，未保存时返回 nil。
    public func storedBottomPanelHeight(for viewContainerID: String) -> CGFloat? {
        bottomPanelHeights[viewContainerID]
    }

    /// 设置指定视图容器的底部面板高度，值变化时发出通知（由插件负责持久化）。
    public func setBottomPanelHeight(_ height: CGFloat, for viewContainerID: String) {
        guard bottomPanelHeights[viewContainerID] != height else { return }
        bottomPanelHeights[viewContainerID] = height
        if Self.verbose {
            Self.logger.info("\(Self.t)bottomPanelHeight[\(viewContainerID)] → \(height)")
        }
        NotificationCenter.postBottomPanelHeightDidChange(containerID: viewContainerID, height: height)
    }

    /// 内部回填底部面板高度（恢复时使用，不发通知）。
    public func restoreBottomPanelHeight(_ height: CGFloat, for viewContainerID: String) {
        bottomPanelHeights[viewContainerID] = height
    }

    private func chatSectionWidthKey(
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
