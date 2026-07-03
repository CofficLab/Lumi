import Combine
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

    // MARK: - 初始化

    public init() {}

    // MARK: - 公开方法

    /// 激活指定视图容器
    public func activateViewContainer(id: String) {
        activeViewContainerID = id
    }

    /// 清除当前激活的视图容器
    public func clearActiveViewContainer() {
        activeViewContainerID = nil
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
