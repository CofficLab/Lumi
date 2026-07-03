import LumiCoreKit
import MagicLog
import SwiftUI
import Combine
import os

/// 布局持久化插件
///
/// 负责将 `LumiCore.layoutState` 的变化持久化到磁盘，
/// 并在 App 启动时从磁盘恢复已保存的布局状态。
///
/// 内核只提供 `@Published` 响应式状态和全局 `LumiCore.layoutState` 入口，
/// 本插件通过订阅内核状态实现持久化，内核不知道插件的存在。
public enum LayoutPlugin: LumiPlugin, SuperLog {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "sidebar.left"
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    public nonisolated static let emoji = "📐"
    public nonisolated static let verbose = true

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.layout",
        displayName: LumiPluginLocalization.string("Layout Persistence", bundle: .module),
        description: LumiPluginLocalization.string("Persist and restore layout state across app launches", bundle: .module),
        order: 99
    )

    // MARK: - LumiPlugin Lifecycle

    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) {
        switch event {
        case .didRegister:
            break
        case .appDidLaunch:
            if Self.verbose {
                Self.logger.info("\(Self.t)开始恢复布局状态")
            }
            LayoutPersistenceCoordinator.shared.restore(from: LayoutPluginLocalStore.shared)
        case .projectDidOpen:
            break
        case .projectDidClose:
            break
        }
    }

    // MARK: - LumiPlugin Implementation

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                LayoutPersistenceAnchor(content: content)
            }
        ]
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(info.id).layout-menu",
                title: LumiPluginLocalization.string("Layout", bundle: .module),
                placement: .trailing
            ) {
                LayoutMenuButton()
            }
        ]
    }
}

// MARK: - Persistence Coordinator

/// 布局持久化协调器
///
/// 负责将内核 `LumiLayoutState` 的变化同步到 `LayoutPluginLocalStore`，
/// 并在 App 启动时从磁盘恢复状态。
@MainActor
final class LayoutPersistenceCoordinator {
    static let shared = LayoutPersistenceCoordinator()

    private var cancellables = Set<AnyCancellable>()
    private let store = LayoutPluginLocalStore.shared

    private init() {}

    /// 开始监听内核状态变化并持久化
    func startObserving(_ state: LumiLayoutState) {
        cancellables.removeAll()

        if LayoutPlugin.verbose {
            LayoutPlugin.logger.info("\(LayoutPlugin.t)开始监听内核状态变化")
        }

        // activeViewContainerID
        state.$activeViewContainerID
            .removeDuplicates()
            .sink { [weak self] value in
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)activeViewContainerID → \(value ?? "nil")")
                }
                self?.store.saveActiveViewContainerID(value)
            }
            .store(in: &cancellables)

        // activeRailTabID
        state.$activeRailTabID
            .removeDuplicates()
            .sink { [weak self] value in
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)activeRailTabID → \(value)")
                }
                self?.store.saveSelectedAgentSidebarTabId(value)
            }
            .store(in: &cancellables)

        // activeBottomTabID
        state.$activeBottomTabID
            .removeDuplicates()
            .sink { [weak self] value in
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)activeBottomTabID → \(value)")
                }
                self?.saveActiveBottomTabID(value)
            }
            .store(in: &cancellables)

        // bottomPanelVisible
        state.$bottomPanelVisible
            .removeDuplicates()
            .sink { [weak self] value in
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)bottomPanelVisible → \(value)")
                }
                self?.store.saveBottomPanelVisible(value)
            }
            .store(in: &cancellables)

        // chatSectionVisible
        state.$chatSectionVisible
            .removeDuplicates()
            .sink { [weak self] value in
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)chatSectionVisible → \(value)")
                }
                self?.saveChatSectionVisible(value)
            }
            .store(in: &cancellables)
    }

    /// 从磁盘恢复布局状态到内核
    func restore(from store: LayoutPluginLocalStore) {
        guard let state = LumiCore.layoutState else {
            if LayoutPlugin.verbose {
                LayoutPlugin.logger.warning("\(LayoutPlugin.t)LumiCore.layoutState 未初始化，跳过恢复")
            }
            return
        }

        var restored: [String] = []

        if let id = store.loadActiveViewContainerID() {
            state.activeViewContainerID = id
            restored.append("activeViewContainerID=\(id)")
        }
        if let tabId = store.loadSelectedAgentSidebarTabId() {
            state.activeRailTabID = tabId
            restored.append("activeRailTabID=\(tabId)")
        }
        if let bottomTabId = loadActiveBottomTabID() {
            state.activeBottomTabID = bottomTabId
            restored.append("activeBottomTabID=\(bottomTabId)")
        }
        if let visible = store.loadBottomPanelVisible() {
            state.bottomPanelVisible = visible
            restored.append("bottomPanelVisible=\(visible)")
        }
        if let visible = store.loadContentPanelVisible() {
            state.chatSectionVisible = visible
            restored.append("chatSectionVisible=\(visible)")
        }

        if LayoutPlugin.verbose {
            if restored.isEmpty {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)磁盘无已保存布局，使用默认值")
            } else {
                LayoutPlugin.logger.info("\(LayoutPlugin.t)已从磁盘恢复布局: \(restored.joined(separator: ", "))")
            }
        }

        // 开始监听后续变化
        startObserving(state)
    }

    // MARK: - Bottom Tab ID & Chat Section Visibility (extra keys not in store convenience API)

    private static let bottomTabIDKey = "activeBottomTabID"
    private static let chatSectionVisibleKey = "chatSectionVisible"

    private func saveActiveBottomTabID(_ value: String) {
        store.set(value, forKey: Self.bottomTabIDKey)
    }

    private func loadActiveBottomTabID() -> String? {
        store.string(forKey: Self.bottomTabIDKey)
    }

    private func saveChatSectionVisible(_ value: Bool) {
        store.set(value, forKey: Self.chatSectionVisibleKey)
    }
}

// MARK: - Persistence Anchor

private struct LayoutPersistenceAnchor: View {
    let content: AnyView

    var body: some View {
        content
            .onAppear {
                if LayoutPlugin.verbose {
                    LayoutPlugin.logger.info("\(LayoutPlugin.t)布局持久化锚点已挂载")
                }
                // 确保协调器开始监听（restore 已在 appDidLaunch 中调用）
                _ = LayoutPersistenceCoordinator.shared
            }
    }
}
