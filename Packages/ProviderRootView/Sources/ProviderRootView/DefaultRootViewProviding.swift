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
/// - ActivityBar 仅在已注册容器数 > 1 时显示；
/// - Rail 仅在存在活跃容器（且容器可见）时显示；
/// - 根视图应用主题背景、`appThemedAppearance`、`ThemeWindowAppearanceBridge`
///   与 `AppThemeVM` 环境对象（复刻旧版主题链）。
@MainActor
public final class DefaultRootViewProviding: RootViewProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-root-view", category: "ProviderRootView")
    nonisolated public static let emoji = "🏠"
    nonisolated static let verbose = true

    @Published fileprivate var toolbarView: AnyView?
    @Published fileprivate var activityBarView: AnyView?
    @Published fileprivate var railView: AnyView?
    @Published fileprivate var contentView: AnyView?
    @Published fileprivate var trailingPane: RootTrailingPane?
    fileprivate var workspaceProvider: (any WorkspaceProviding)?
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
        return AnyView(DefaultRootHostView(provider: self))
    }

    // MARK: - 显示条件（复刻旧版 AppLayoutView）

    /// 与旧版 `showsActivityBar && activityBarContainerCount > 1` 一致：
    /// 容器数 ≤ 1 时整条 ActivityBar 隐藏（仅剩一个入口时无需竖直选择栏）。
    fileprivate var showsActivityBar: Bool {
        guard let activityBarView else { return false }
        guard let workspaceProvider else { return true }
        return workspaceProvider.containers.count > 1
    }

    /// 是否存在活跃容器（旧版 `activeViewContainerID != nil` 且容器可解析）。
    fileprivate var hasActiveContainer: Bool {
        guard let containerID = workspaceProvider?.activeContainerID else { return false }
        return workspaceProvider?.container(id: containerID) != nil
    }

    /// 当前活跃容器 ID（无容器时回退 "root"）。
    fileprivate var containerID: String {
        workspaceProvider?.activeContainerID ?? "root"
    }
}

@MainActor
private struct DefaultRootHostView: View {
    @ObservedObject var provider: DefaultRootViewProviding
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            if let toolbarView = provider.toolbarView {
                toolbarView
                // 与旧版 AppLayoutView 一致：工具栏下方使用主题分隔线。
                AppDivider()
            }

            HStack(spacing: 0) {
                if provider.showsActivityBar, let activityBarView = provider.activityBarView {
                    activityBarView
                    // 与旧版 AppLayoutView 一致：ActivityBar 右侧使用主题竖向分隔线。
                    AppDivider(.vertical)
                }

                WorkbenchSplitView(provider: provider)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
        .environmentObject(AppThemeVM.shared)
        #if os(macOS)
        .ignoresSafeArea()
        #endif
    }
}

@MainActor
private struct WorkbenchSplitView: View {
    @ObservedObject var provider: DefaultRootViewProviding

    private var workspace: (any WorkspaceProviding)? { provider.workspaceProvider }
    private var containerID: String { provider.containerID }
    private var showsRail: Bool {
        provider.railView != nil
            && provider.hasActiveContainer
            && (workspace?.isRailVisible ?? true)
    }

    var body: some View {
        Group {
            if provider.hasActiveContainer {
                if showsRail {
                    #if os(macOS)
                    HSplitView {
                        provider.railView!
                            .frame(minWidth: 180, idealWidth: workspace?.railDivider(for: containerID, fallback: 240) ?? 240, maxWidth: 400)
                            // 与旧版 AppLayoutView 一致：Rail pane 的右侧分割线样式 + 拖拽后同步宽度。
                            .appSplitDivider(.trailing, initialPosition: workspace?.railDivider(for: containerID, fallback: 240) ?? 240) { position in
                                workspace?.setRailDivider(position, for: containerID)
                            }
                        mainContent
                    }
                    .id("host.rail.\(containerID)")
                    #else
                    HStack(spacing: 0) { provider.railView!; Divider(); mainContent }
                    #endif
                } else {
                    mainContent
                }
            } else {
                // 与旧版 AppLayoutView 一致：无活跃容器时显示欢迎占位。
                RootWelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        RootMainContentView(
            contentView: provider.contentView,
            trailingPane: provider.trailingPane,
            workspaceShowsTrailingPane: workspace?.isChatVisible ?? true,
            trailingWidth: workspace?.chatDivider(for: containerID, layout: .narrow, fallback: 320) ?? 320,
            containerID: containerID,
            workspace: workspace
        )
    }
}

@MainActor
private struct RootMainContentView: View {
    let contentView: AnyView?
    @ObservedObject var trailingPane: RootTrailingPane
    let workspaceShowsTrailingPane: Bool
    let trailingWidth: CGFloat
    let containerID: String
    let workspace: (any WorkspaceProviding)?

    init(
        contentView: AnyView?,
        trailingPane: RootTrailingPane?,
        workspaceShowsTrailingPane: Bool,
        trailingWidth: CGFloat,
        containerID: String,
        workspace: (any WorkspaceProviding)?
    ) {
        self.contentView = contentView
        self.workspaceShowsTrailingPane = workspaceShowsTrailingPane
        self.trailingWidth = trailingWidth
        self.containerID = containerID
        self.workspace = workspace
        _trailingPane = ObservedObject(wrappedValue: trailingPane ?? RootTrailingPane(
            id: "root.empty",
            isVisible: false,
            content: AnyView(EmptyView())
        ))
    }

    private var mainContent: AnyView {
        contentView ?? AnyView(ContentPlaceholderView())
    }

    var body: some View {
        Group {
            if trailingPane.isVisible && workspaceShowsTrailingPane {
                #if os(macOS)
                HSplitView {
                    mainContent
                        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                        // 与旧版 AppLayoutView 一致：内容区 pane 的右侧分割线样式 + 拖拽后同步宽度。
                        .appSplitDivider(.trailing, initialPosition: trailingWidth) { position in
                            workspace?.setChatDivider(position, for: containerID, layout: .narrow)
                        }
                    trailingPane.content
                        .frame(
                            minWidth: trailingPane.minWidth,
                            idealWidth: trailingWidth,
                            maxWidth: trailingPane.maxWidth,
                            maxHeight: .infinity
                        )
                }
                // 与旧版 AppLayoutView 一致：切换容器时保留 Chat 分割状态。
                .id("host.chat.\(containerID)")
                #else
                HStack(spacing: 0) {
                    mainContent
                    Divider()
                    trailingPane.content
                        .frame(minWidth: trailingPane.minWidth, idealWidth: trailingPane.idealWidth)
                }
                #endif
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 无活跃容器时的欢迎占位（复刻旧版 `WelcomeView`）。
///
/// 与旧版完全一致：主题色图标 + 标题 + 引导文案 + 主题径向渐变背景。
@MainActor
private struct RootWelcomeView: View {
    @LumiTheme private var theme

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()

                Image(systemName: "rectangle.center.inset.filled")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.primary)
                    .scaledToFit()
                    .frame(maxHeight: 80)

                VStack(spacing: DesignTokens.Spacing.md) {
                    Text("Welcome to Lumi")
                        .font(.appTitle)
                        .foregroundStyle(theme.textPrimary)

                    Text("Select an item from the ActivityBar to get started")
                        .font(.appBody)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var backgroundView: some View {
        GeometryReader { geometry in
            let maxRadius = max(geometry.size.width, geometry.size.height)

            RadialGradient(
                gradient: Gradient(colors: [
                    theme.primary.opacity(0.06),
                    theme.primary.opacity(0.02),
                    theme.background.opacity(0)
                ]),
                center: .center,
                startRadius: 0,
                endRadius: maxRadius * 0.8
            )
            .ignoresSafeArea()
        }
    }
}

/// 内容区占位视图（有活跃容器但未注入内容时）。
private struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Root View")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
