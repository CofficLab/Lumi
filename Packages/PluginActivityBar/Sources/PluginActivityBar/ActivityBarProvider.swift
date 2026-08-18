import Foundation
import os
import SwiftUI
import KernelCore
import LumiUI
import ProviderActivityBar
import SuperLogKit

/// 自定义 `ActivityBarProviding` 实现。
///
/// 复刻旧版 `FactoryCore.ActivityBar` 的视觉与交互，**完全自实现**：
/// - 自行维护 `items`（按 `order` 排序）、`activeItemID` 与激活回调，
///   不封装/委托 `DefaultActivityBarProviding`；
/// - 自行渲染竖直入口栏视图（48pt 宽、顶部渐隐滚动列表、右侧分隔线、
///   右键「打开设置」等），与 `DefaultActivityBarProviding` 视觉保持一致；
/// - 在 `onReady` 阶段把本插件维护的"内置默认入口"作为初始入口合并进去，
///   便于宿主在不引入其他业务插件时也能看到 ActivityBar 入口；
/// - 暴露 `customItems` 数组供业务插件继续附加入口（不会清空 builtin）。
///
/// 替换 `ProviderFactory` 预注册的 `DefaultActivityBarProviding` 后，
/// 后续 `kernel.resolveProvider((any ActivityBarProviding).self)` 拿到的就是本实现。
@MainActor
public final class ActivityBarProvider: ActivityBarProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.activity-bar", category: "Provider")
    nonisolated public static let emoji = "🧱"
    nonisolated static let verbose = false

    /// 当前已激活入口的 id。
    @Published public private(set) var activeItemID: String?

    /// 当前已注入的全部 ActivityBar 项（按 `order` 排序）。
    @Published public private(set) var items: [ActivityBarItem] = []

    /// 本插件自带的"内置默认入口"id，方便业务插件在 `onReady` 期辨识。
    public static let builtInItemIDs: Set<String> = [
        "com.coffic.lumi.plugin.activity-bar.welcome",
    ]

    /// 已被业务插件追加/移除的入口历史（仅日志诊断用）。
    public private(set) var customItems: [ActivityBarItem] = []

    /// 隐藏缓存：按插件 id 存储被隐藏的入口，以便插件重新启用时恢复。
    private var hiddenItemCache: [String: [ActivityBarItem]] = [:]

    public init() {}

    /// 用一组已存在的内容（即将被替换的旧 `DefaultActivityBarProviding` 数据）
    /// 预填新实例，确保 `unregisterProvider` 之后业务插件已注册的 `ActivityBarItem`
    /// 与激活态不会丢失。
    ///
    /// 调用场景：见 `PluginActivityBar.onBoot`——
    /// 多个业务插件（如 `PluginChatPanel`/`PluginDevice`/`PluginDiskManager`/...）
    /// 在 `onBoot` 中调用 `addItems(...)` 写入 ProviderFactory 预注册的默认实例；
    /// 本插件（`order=10`，晚于 `PluginChatPanel` 的 order=2）要在 `onBoot` 中
    /// `unregisterProvider` + `registerProvider` 替换为自定义实例。如果直接丢弃旧
    /// 实例，前序业务插件写入的 items 就会跟着默认实例一起被释放。
    ///
    /// - Parameters:
    ///   - items: 旧实例已注入的全部 ActivityBar 项（按 `order` 排序后传入，
    ///     调用方无需关心顺序）。
    ///   - activeItemID: 旧实例当前激活项；若传入 id 在 `items` 中不存在则被忽略。
    public convenience init(preloadedItems items: [ActivityBarItem], activeItemID: String? = nil) {
        self.init()
        // 走 `registerItems` 走默认路径（按 order 排序、激活态校验），复用本类统一逻辑。
        registerItems(items)
        if let activeItemID {
            activateItem(id: activeItemID)
        }
    }

    /// 注入/替换全部入口（按 `order` 排序，并校正激活态）。
    ///
    /// 完全自实现：与 `DefaultActivityBarProviding` 保持一致的排序与激活回退语义。
    public func registerItems(_ items: [ActivityBarItem]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)替换入口：\(items.count, privacy: .public) 项")
        }
        self.items = items.sorted { $0.order < $1.order }

        // 激活态校正：当前激活项若仍存在则保留，否则回退到首个（无入口时 nil）。
        let nextActiveID: String?
        if let activeItemID, self.items.contains(where: { $0.id == activeItemID }) {
            nextActiveID = activeItemID
        } else {
            nextActiveID = self.items.first?.id
        }
        setActiveItemID(nextActiveID)

        // 局部缓存，便于日志/调试观察。
        customItems = self.items.filter { !Self.builtInItemIDs.contains($0.id) }
    }

    /// 追加入口，保留已有项。复用协议的默认合并实现。
    public func addItems(_ items: [ActivityBarItem]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)追加入口：\(items.count, privacy: .public) 项")
        }
        var merged = self.items
        for item in items where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerItems(merged)
    }

    /// 按 id 移除入口。复用协议默认实现。
    public func removeItems(ids: Set<String>) {
        if Self.verbose {
            Self.logger.info("\(Self.t)移除入口：\(ids.count, privacy: .public) 项")
        }
        registerItems(self.items.filter { !ids.contains($0.id) })
    }

    /// 激活指定入口。未知 id 忽略；传 nil 表示清除激活。
    public func activateItem(id: String?) {
        if Self.verbose {
            Self.logger.info("\(Self.t)activate: \(id ?? "nil", privacy: .public)")
        }
        guard id == nil || items.contains(where: { $0.id == id }) else { return }
        setActiveItemID(id)
    }

    /// 返回 ActivityBar 视图（基于本类自渲染的竖直入口栏）。
    public func makeActivityBarView() -> AnyView {
        AnyView(ActivityBarView(provider: self))
    }

    /// 把插件"内置默认入口"作为初始 items 注入，便于宿主在不引入其他业务插件时
    /// ActivityBar 也能看到一条"欢迎"入口。
    ///
    /// 业务插件在 `kernel.start(plugins:)` 之后（`onReady` 阶段）调用本方法，
    /// 确保后续 `addItems` 不会覆盖 builtin。
    ///
    /// 注意：使用 `addItems`（合并）而非 `registerItems`（替换），以保留
    /// `onBoot` 阶段迁移过来的旧实例 items（典型如 `PluginChatPanel` 写入的 chat 入口）。
    public func bootstrapBuiltInItems() {
        let builtIn: [ActivityBarItem] = [
            ActivityBarItem(
                id: "com.coffic.lumi.plugin.activity-bar.welcome",
                title: "Welcome",
                systemImage: "sparkles",
                order: 50
            ),
        ]
        addItems(builtIn)
    }

    // MARK: - Plugin Lifecycle Observation

    /// 按插件 id 隐藏入口：将该插件贡献的全部入口从可见列表移入隐藏缓存。
    ///
    /// 被隐藏的入口在插件重新启用时可通过 `restoreItems(forPluginID:)` 恢复。
    /// 内置入口（`ownerPluginID == nil`）不受影响。
    public func hideItems(forPluginID pluginID: String) {
        let hidden = items.filter { $0.ownerPluginID == pluginID }
        guard !hidden.isEmpty else { return }
        hiddenItemCache[pluginID, default: []].append(contentsOf: hidden)
        let idsToHide = Set(hidden.map(\.id))
        let remaining = items.filter { !idsToHide.contains($0.id) }
        registerItems(remaining)
        if Self.verbose {
            Self.logger.info("\(Self.t)隐藏插件 \(pluginID, privacy: .public) 的 \(hidden.count, privacy: .public) 个入口")
        }
    }

    /// 按插件 id 恢复之前被隐藏的入口。
    ///
    /// 插件重新启用时调用，将隐藏缓存中的入口重新合入可见列表。
    public func restoreItems(forPluginID pluginID: String) {
        guard let cached = hiddenItemCache.removeValue(forKey: pluginID), !cached.isEmpty else { return }
        addItems(cached)
        if Self.verbose {
            Self.logger.info("\(Self.t)恢复插件 \(pluginID, privacy: .public) 的 \(cached.count, privacy: .public) 个入口")
        }
    }

    // MARK: - Private

    /// 更新激活态，仅在实际变化时触发 `@Published` 变更与全部已注册项的回调。
    private func setActiveItemID(_ id: String?) {
        guard activeItemID != id else { return }
        activeItemID = id
        for item in items {
            item.onActiveItemChanged(id)
        }
    }
}

// MARK: - Views

/// 竖直渲染 ActivityBar 项的视图。
///
/// 视觉与旧版 `FactoryCore.ActivityBar` 保持一致（即与 `DefaultActivityBarProviding`
/// 相同的渲染），但在此**完全自实现**，不依赖 `DefaultActivityBarProviding`：
/// - 48pt 宽的 `.panel` 表面 + 右侧 `theme.divider` 分隔线（`borderTrailing()`）；
/// - 每个入口复用 `AppActivityIconButton`（18pt 图标、左侧 2.5pt 主题色指示条、
///   hover 高亮与 LumiMotion 动画），激活态由 `activeItemID` 判定；
/// - 内容溢出时滚动，配合上下 8pt 渐隐遮罩提示可滚动；
/// - 右键菜单提供「打开设置」入口（与旧版一致，通过 `lumi.openSettings` 通知）。
private struct ActivityBarView: View {
    @ObservedObject var provider: ActivityBarProvider

    var body: some View {
        VStack(spacing: 6) {
            if provider.items.isEmpty {
                Spacer(minLength: 0)
            } else {
                ActivityBarScrollableItemList(
                    items: provider.items,
                    activeItemID: provider.activeItemID
                ) { item in
                    provider.activateItem(id: item.id)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .frame(maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
        .borderTrailing()
        .contextMenu {
            Button {
                NotificationCenter.default.post(name: .lumiOpenSettings, object: nil)
            } label: {
                Label("打开设置", systemImage: "gearshape")
            }
        }
    }
}

/// ActivityBar 可滚动的入口列表（与旧版 `ActivityBarScrollableContainerList` 行为一致）：
/// - 内容溢出时启用滚动（隐藏系统滚动指示器，顶部/底部 8pt 渐隐遮罩暗示可滚动）；
/// - 内容不足时退化为普通垂直布局，不显示任何滚动提示。
private struct ActivityBarScrollableItemList: View {
    private let fadeHeight: CGFloat = 8

    let items: [ActivityBarItem]
    let activeItemID: String?
    let onSelect: (ActivityBarItem) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(items) { item in
                    AppActivityIconButton(
                        systemImage: item.systemImage,
                        label: item.title,
                        isActive: activeItemID == item.id
                    ) {
                        onSelect(item)
                    }
                    .id(item.id)
                }
            }
            .padding(.vertical, 2)
        }
        .mask(fadeMask)
    }

    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)

            Color.black

            LinearGradient(
                colors: [Color.black, Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: fadeHeight)
        }
    }
}

/// 打开设置窗口的通知名（与 KernelLumi 的 `lumi.openSettings` 同字符串，通知可互通）。
private extension Notification.Name {
    static let lumiOpenSettings = Notification.Name("lumi.openSettings")
}
