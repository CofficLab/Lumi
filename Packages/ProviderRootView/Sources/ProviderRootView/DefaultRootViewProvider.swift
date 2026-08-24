import Combine
import LumiUI
import os
import ProviderWorkspace
import SuperLogKit
import SwiftUI

/// `RootViewProviding` 的默认实现：持有注入的工具栏、ActivityBar、Rail
/// 与主内容视图，组合成「顶部工具栏 + 内容区（左侧 ActivityBar，右侧 Rail）」
/// 的根布局（与旧版 `AppLayoutView` 完全一致）。
///
/// 与旧版 `AppLayoutView` 对齐的行为：
/// - 主内容未注入、且无活跃容器时显示 `WelcomeView` 风格的欢迎占位；
/// - ActivityBar 始终显示；
/// - Rail 仅在存在活跃容器（且容器可见）时显示；
/// - 根视图应用主题背景、`appThemedAppearance`、`ThemeWindowAppearanceBridge`
///   与 `AppThemeVM` 环境对象（复刻旧版主题链）。
@MainActor
public final class DefaultRootViewProvider: RootViewProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-root-view", category: "ProviderRootView")
    nonisolated public static let emoji = "🏠"
    nonisolated static let verbose = false

    @Published var toolbarView: AnyView?
    @Published var activityBarView: AnyView?
    @Published var railView: AnyView?
    @Published var contentView: AnyView?
    @Published var trailingPane: RootTrailingPane?
    @Published public private(set) var overlays: [RootOverlayItem] = []
    var workspaceProvider: (any WorkspaceProviding)?
    private var workspaceSubscription: AnyCancellable?

    public init() {
        if Self.verbose {
            Self.logger.info("\(self.t)DefaultRootViewProviding initialized")
        }
    }

    public func setToolbarView(_ view: AnyView?) {
        guard !isSameView(toolbarView, view) else { return }
        toolbarView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set toolbar view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func addOverlays(_ newOverlays: [RootOverlayItem]) {
        for overlay in newOverlays where !overlays.contains(where: { $0.id == overlay.id }) { overlays.append(overlay) }
        overlays.sort { $0.order < $1.order }
    }

    public func removeOverlays(ids: Set<String>) { overlays.removeAll { ids.contains($0.id) } }

    public func setActivityBarView(_ view: AnyView?) {
        guard !isSameView(activityBarView, view) else { return }
        activityBarView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set activity bar view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setRailView(_ view: AnyView?) {
        guard !isSameView(railView, view) else { return }
        railView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set rail view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setContentView(_ view: AnyView?) {
        guard !isSameView(contentView, view) else { return }
        contentView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set content view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setTrailingPane(_ pane: RootTrailingPane?) {
        guard pane !== trailingPane else { return }
        trailingPane = pane
        if Self.verbose {
            Self.logger.debug("\(self.t)set trailing pane: \(pane.map { $0.id } ?? "nil")")
        }
    }

    public func setWorkspaceProvider(_ provider: (any WorkspaceProviding)?) {
        guard provider !== workspaceProvider else { return }
        workspaceProvider = provider
        workspaceSubscription = provider?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        objectWillChange.send()
        if Self.verbose {
            Self.logger.debug("\(self.t)set workspace provider: \(provider == nil ? "nil" : "injected")")
        }
    }

    // MARK: - 注入守卫（值相同则跳过赋值）

    /// 判断两次注入的视图是否「相同」：仅比较有值/无值状态。
    ///
    /// `AnyView` 不遵循 `Equatable`，SwiftUI 也未公开 unerase API（反射内部
    /// storage 在 Release 下不可靠）。因此这里采用保守且可预测的判定：
    /// - 状态相同（均为 nil 或均为非 nil）→ 视为相同，跳过赋值；
    /// - 状态不同（nil ↔ 非 nil）→ 视为变化，正常更新。
    ///
    /// 目的：装配流程可能重复调用注入方法（如 Kernel 转发 `objectWillChange`
    /// 导致 App body 重求值后再次装配），重复赋值 `@Published` 会在视图更新期间
    /// 发布变更，触发 SwiftUI 的 "Publishing changes from within view updates
    /// is not allowed" 并可能形成循环。状态相同即跳过，避免无意义发布。
    ///
    /// 注意：这是保守近似 —— 已注入非 nil 视图后，再次注入任意新视图（含不同
    /// 类型）都会被跳过。Lumi 架构下视图内容更新由视图内部状态驱动（Provider
    /// 的 `@Published`/`objectWillChange`），无需重新注入新 `AnyView`；若确有
    /// Provider 需要强制替换，可先传 nil 再传新值。
    private func isSameView(_ lhs: AnyView?, _ rhs: AnyView?) -> Bool {
        (lhs == nil) == (rhs == nil)
    }

    public func makeRootView() -> AnyView {
        if Self.verbose {
            Self.logger.debug("\(self.t)make root view: toolbar=\(self.toolbarView == nil ? "nil" : "set"), activityBar=\(self.activityBarView == nil ? "nil" : "set"), rail=\(self.railView == nil ? "nil" : "set"), content=\(self.contentView == nil ? "nil" : "set"), activeContainer=\(self.containerID)")
        }
        var root = AnyView(DefaultRootHostView(provider: self))
        for overlay in overlays { root = overlay.wrap(root) }
        return root
    }

    // MARK: - 显示条件

    /// 是否存在活跃容器（旧版 `activeViewContainerID != nil` 且容器可解析）。
    var hasActiveContainer: Bool {
        guard let containerID = workspaceProvider?.activeContainerID else { return false }
        return workspaceProvider?.container(id: containerID) != nil
    }

    /// 当前活跃容器 ID（无容器时回退 "root"）。
    var containerID: String {
        workspaceProvider?.activeContainerID ?? "root"
    }
}
