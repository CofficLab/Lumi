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
public final class LayoutState: ObservableObject, SuperLog {
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

    @Published public var activeViewContainerTitle: String = "Main" {
        didSet {
            guard activeViewContainerTitle != oldValue else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)activeViewContainerTitle → \(self.activeViewContainerTitle)")
            }
        }
    }

    @Published public var currentChatSection: LumiChatSectionLayout = .none {
        didSet {
            guard currentChatSection != oldValue else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)currentChatSection → \(currentChatSection)")
            }
        }
    }

    @Published public var showsRail: Bool = false {
        didSet {
            guard showsRail != oldValue else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)showsRail → \(showsRail)")
            }
        }
    }

    @Published public var showsPanelChrome: Bool = false {
        didSet {
            guard showsPanelChrome != oldValue else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)showsPanelChrome → \(showsPanelChrome)")
            }
        }
    }

    @Published public var isChatSectionVisible: Bool = false {
        didSet {
            guard isChatSectionVisible != oldValue else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)isChatSectionVisible → \(isChatSectionVisible)")
            }
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
    @Published private(set) public var bottomPanelFocusGeneration = 0

    /// 底部面板 tab 的全局默认值（未被显式选择过的容器回退到此值）。
    public static let defaultBottomTabID = "editor-bottom-problems"

    // MARK: - 设置窗口状态

    /// 当前选中的设置标签 ID。
    ///
    /// 格式为 `"<category>.<tab>"`，例如：
    /// - `"core.general"` - 核心设置-常规
    /// - `"core.appearance"` - 核心设置-外观
    /// - `"plugin.<pluginID>"` - 插件设置
    ///
    /// 由 SettingsView 在用户切换标签时更新，持久化后下次打开设置窗口可恢复选择。
    @Published public var selectedSettingsTabID: String? {
        didSet {
            guard self.selectedSettingsTabID != oldValue else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)selectedSettingsTabID → \(self.selectedSettingsTabID ?? "nil")")
            }
        }
    }

    // MARK: - 恢复状态

    /// 布局状态是否已完成从磁盘恢复。
    ///
    /// 启动早期由 `LayoutPersistenceCoordinator.restore()` 标记为 true（在 `RootContainer.init`
    /// 同步阶段调用一次）。在此之前，UI 层的默认选择逻辑（`selectDefaultContainerIfNeeded`）
    /// 应跳过写入 `activeViewContainerID`，避免首帧默认值覆盖即将恢复的持久化值。
    ///
    /// 默认 false：若极端情况下 restore 未走到 `markLayoutRestored()`，UI 会回退到
    /// `selectedContainer` 的 `containers.first` 分支，仍可用，只是不恢复历史选择。
    @Published public private(set) var isLayoutRestored: Bool = false

    /// 标记布局恢复完成。由持久化协调器在 `restore()` 结束时调用一次。
    public func markLayoutRestored() {
        isLayoutRestored = true
    }

    // MARK: - 分栏 divider 位置状态

    /// 各视图容器的 Rail divider 位置（HSplitView 中 divider 0 的 x 坐标 = pane 0 宽度 = Rail 宽度）。
    @Published private var railDividers: [String: CGFloat] = [:]
    /// 各视图容器的聊天区 divider 位置，key 形如 `<viewContainerID>.<layoutSuffix>`。
    @Published private var chatSectionDividers: [String: CGFloat] = [:]
    /// 各视图容器的底部面板 divider 位置（VSplitView 中 divider 0 的 y 坐标 = pane 0 高度 = 内容区高度）。
    /// 注意：这是 pane 0（内容区）的高度，不是 pane 1（底部面板）的高度——它只是 NSSplitView 视角的"divider 在哪"。
    @Published private var bottomPanelDividers: [String: CGFloat] = [:]
    /// 各视图容器选中的底部面板 tab。key 为 viewContainerID，value 为 tab id。
    @Published private var activeBottomTabIDs: [String: String] = [:]
    /// v1 → v2 迁移的 legacy 值：所有容器共享的默认回退 bottom tab ID。
    @Published private(set) var legacyBottomTabID: String?

    /// 各视图容器的 panel column 宽度（= rail 所在 HSplitView 的 bounds.width = 整个左侧栏宽度）。
    /// 由视图层（`SplitDividerPersistenceView`）在每次 didResize 时持续同步，
    /// 仅用于"三栏宽度"日志中推算 middle = panelColumn - rail。不参与持久化、也不发通知。
    private var panelColumnWidths: [String: CGFloat] = [:]

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
        logThreeColumnWidths(for: viewContainerID)
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
        logThreeColumnWidths(for: viewContainerID)
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

    // MARK: - 底部面板 Tab 选中（per-container）

    /// 获取指定容器的底部面板 tab ID。
    /// 查找顺序：per-container 字典 → legacy 默认值 → 系统默认值。
    public func activeBottomTabID(for viewContainerID: String) -> String {
        activeBottomTabIDs[viewContainerID] ?? legacyBottomTabID ?? Self.defaultBottomTabID
    }

    /// 设置指定容器的底部面板 tab ID，值变化时发出通知。
    public func setActiveBottomTabID(_ id: String, for viewContainerID: String) {
        guard activeBottomTabIDs[viewContainerID] != id else { return }
        activeBottomTabIDs[viewContainerID] = id
        if Self.verbose {
            Self.logger.info("\(Self.t)activeBottomTabID[\(viewContainerID)] → \(id)")
        }
        NotificationCenter.postActiveBottomTabIDDidChange(containerID: viewContainerID, bottomTabID: id)
    }

    /// 内部回填底部面板 tab（恢复时使用，不发通知）。
    public func restoreActiveBottomTabID(_ id: String, for viewContainerID: String) {
        activeBottomTabIDs[viewContainerID] = id
    }

    /// 内部回填 legacy 默认底部面板 tab（v1 → v2 迁移时使用，不发通知）。
    public func restoreLegacyBottomTabID(_ id: String) {
        legacyBottomTabID = id
    }

    private func chatSectionDividerKey(
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> String {
        "\(viewContainerID).\(layout.persistenceKeySuffix)"
    }

    // MARK: - Panel column 宽度（仅供"三栏宽度"日志使用，不参与持久化）

    /// 同步指定视图容器的 panel column 宽度（= rail 所在 HSplitView 的 bounds.width）。
    ///
    /// 由视图层在 didResize 时调用，给"三栏宽度"日志提供 middle = panelColumn - rail 的推算依据。
    /// 不发通知、不参与持久化；仅作日志快照。值 <= 0 时忽略。
    public func setPanelColumnWidth(_ width: CGFloat, for viewContainerID: String) {
        guard width > 0 else { return }
        panelColumnWidths[viewContainerID] = width
    }

    /// 读取最近一次同步进来的 panel column 宽度，从未同步过则返回 nil。
    public func panelColumnWidth(for viewContainerID: String) -> CGFloat? {
        panelColumnWidths[viewContainerID]
    }

    // MARK: - 三栏宽度日志

    /// 把"rail / middle / chat"三栏当前宽度打到日志。
    ///
    /// 调用时机：`setRailDivider` / `setChatSectionDivider` 在写完新值后。
    /// - `rail` 直接读 `railDividers[viewContainerID]`。
    /// - `middle` = `panelColumn - rail`，依赖视图层通过 `setPanelColumnWidth` 持续同步 panel column。
    /// - `chatDivider` 列出该 viewContainerID 下所有已存储的 chat section divider（每个布局档位一份）。
    ///   命名特意带 "Divider" 后缀——存的**是** A 的 divider 0 位置（即聊天区左边缘 x 坐标），
    ///   **不是**聊天区宽度（宽度 = `A.bounds.width - divider`）。读日志时不要把这个值当宽度看。
    ///   因为一个 view container 可能挂多个 chat section 档位（none / narrow / wide），
    ///   没有"当前档位"概念，全部列出便于人工核对。
    ///
    /// 任一字段缺失时降级为 `n/a`，不全量跳过——保持日志稳定可 grep。
    private func logThreeColumnWidths(for viewContainerID: String) {
        let rail = railDividers[viewContainerID]
        let panel = panelColumnWidths[viewContainerID]
        let middle: CGFloat? = {
            guard let rail, let panel else { return nil }
            return max(0, panel - rail)
        }()
        let chatEntries = chatSectionDividers
            .filter { $0.key.hasPrefix("\(viewContainerID).") }
            .sorted { $0.key < $1.key }
        let chatText: String
        if chatEntries.isEmpty {
            chatText = "n/a"
        } else {
            chatText = chatEntries.map { (k, v) -> String in
                let suffix = k.replacingOccurrences(of: "\(viewContainerID).", with: "")
                return "\(suffix)=\(String(format: "%.1f", v))"
            }.joined(separator: ",")
        }
        let parts: [String] = [
            rail.map { "rail=\(String(format: "%.1f", $0))" } ?? "rail=n/a",
            middle.map { "middle=\(String(format: "%.1f", $0))" } ?? "middle=n/a",
            "chatDivider=[\(chatText)]"
        ]
        Self.logger.info("\(Self.t)三栏宽度[\(viewContainerID)]: \(parts.joined(separator: ", "))")
    }

    // MARK: - Panel Presentation

    public func presentRailTab(id: String) {
        activeRailTabID = id
    }

    public func presentBottomTab(id: String, viewContainerID: String) {
        setActiveBottomTabID(id, for: viewContainerID)
        bottomPanelFocusGeneration += 1
    }
}