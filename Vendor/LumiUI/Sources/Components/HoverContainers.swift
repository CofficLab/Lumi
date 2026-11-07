import Combine
import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
public final class HoverCoordinator: ObservableObject {
    public static let shared = HoverCoordinator()

    @Published public var visibleID: String?

    private var hideWorkItem: DispatchWorkItem?

    public func onHover(id: String, isHovering: Bool) {
        if isHovering {
            hideWorkItem?.cancel()
            hideWorkItem = nil

            if visibleID != id {
                visibleID = id
            }
        } else if visibleID == id {
            let item = DispatchWorkItem { [weak self] in
                if self?.visibleID == id {
                    self?.visibleID = nil
                }
            }
            hideWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
        }
    }

    public func close(id: String) {
        if visibleID == id {
            visibleID = nil
        }
    }

    public func closeAll() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        visibleID = nil
    }

    public func open(id: String) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        visibleID = id
    }
}

public enum HoverContainerChrome {
    case statusBar
    case titleToolbar
}

public struct StatusBarHoverContainer<Content: View, Detail: View>: View {
    let detailView: Detail?
    let content: Content
    let popoverWidth: CGFloat
    let popoverMinHeight: CGFloat
    let id: String
    let arrowEdge: Edge
    let chrome: HoverContainerChrome

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isPresented = false
    @State private var isHovering = false

    public init(
        detailView: Detail,
        popoverWidth: CGFloat = 480,
        popoverMinHeight: CGFloat = 0,
        id: String = UUID().uuidString,
        arrowEdge: Edge = .top,
        chrome: HoverContainerChrome = .statusBar,
        @ViewBuilder content: () -> Content
    ) {
        self.detailView = detailView
        self.content = content()
        self.popoverWidth = popoverWidth
        self.popoverMinHeight = popoverMinHeight
        self.id = id
        self.arrowEdge = arrowEdge
        self.chrome = chrome
    }

    public init(
        id: String = UUID().uuidString,
        chrome: HoverContainerChrome = .statusBar,
        @ViewBuilder content: () -> Content
    ) where Detail == EmptyView {
        self.detailView = nil
        self.content = content()
        self.popoverWidth = 480
        self.popoverMinHeight = 0
        self.id = id
        self.arrowEdge = .top
        self.chrome = chrome
    }

    public var body: some View {
        baseContent
    }

    @ViewBuilder
    private var baseContent: some View {
        let view = content
            .font(.appMicro)
            .foregroundColor(statusItemForeground)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(hoverBackground)
            .animation(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference), value: isHovering || isPresented)
            .onHover { hovering in
                AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)) {
                    isHovering = hovering
                }
            }
            .onTapGesture {
                guard detailView != nil else { return }
                clearAppKitFirstResponder()

                AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.statusPresentation, preference: motionPreference)) {
                    if isPresented {
                        isPresented = false
                        coordinator.close(id: self.id)
                    } else {
                        coordinator.closeAll()
                        isPresented = true
                        coordinator.open(id: self.id)
                    }
                }
            }

        if detailView != nil {
            view.popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
                popoverContent
            }
            .onChange(of: coordinator.visibleID)  { newValue in
                isPresented = newValue == id
            }
        } else {
            view
        }
    }

    private var hoverBackground: some View {
        ZStack {
            if isHovering || isPresented {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(statusItemBackground)
                    .transition(.opacity)
            }
        }
    }

    private var statusItemBackground: Color {
        switch chrome {
        case .statusBar:
            return isPresented ? theme.statusBarItemPresentedBackground : theme.statusBarItemBackground
        case .titleToolbar:
            return isPresented ? theme.primary.opacity(0.14) : theme.textPrimary.opacity(0.08)
        }
    }

    private var statusItemForeground: Color {
        switch chrome {
        case .statusBar:
            return theme.statusBarItemForeground
        case .titleToolbar:
            return theme.textPrimary
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let detailView {
            detailView
                .onHover { hovering in
                    if hovering {
                        coordinator.open(id: self.id)
                    }
                }
                .padding(24)
                .frame(
                    minWidth: popoverWidth,
                    maxWidth: popoverWidth,
                    minHeight: popoverMinHeight > 0 ? popoverMinHeight : nil
                )
                .appSurface(style: .popover, cornerRadius: 12, borderColor: theme.divider)
                .appThemedAppearance()
                .background {
                    #if os(macOS)
                    ThemeWindowAppearanceBridge()
                    #endif
                }
        }
    }
}

public extension StatusBarHoverContainer {
    static func withTextDetail<C: View>(
        _ detailText: String,
        title: String? = nil,
        id: String = UUID().uuidString,
        @ViewBuilder content: @escaping () -> C
    ) -> StatusBarHoverContainer<C, AnyView> {
        let detailContent = AnyView(
            StatusBarTextDetailView(title: title, detailText: detailText)
        )

        return StatusBarHoverContainer<C, AnyView>(
            detailView: detailContent,
            id: id,
            content: content
        )
    }
}

private struct StatusBarTextDetailView: View {
    @LumiTheme private var theme

    let title: String?
    let detailText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.appCallout)
                    .foregroundColor(theme.textPrimary)
            }

            Text(detailText)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .textSelection(.enabled)
        }
    }
}

public struct HoverableContainerView<Content: View, Detail: View>: View {
    let detailView: Detail
    let content: Content
    let id: String

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isPresented = false

    /// 上一帧的 `isPresented` 值。
    ///
    /// macOS 13 的 `onChange(of:)` 单参数版拿不到旧值，这里手动保存快照，
    /// 以维持「值确实发生变化才继续执行」的语义。
    @State private var previousPresentedValue = false

    public init(detailView: Detail, id: String = UUID().uuidString, @ViewBuilder content: () -> Content) {
        self.detailView = detailView
        self.id = id
        self.content = content()
    }

    public var body: some View {
        content
            .background(background(isHovering: isPresented))
            .animation(AppUI.Motion.enabled(AppUI.Motion.statusPresentation, preference: motionPreference), value: isPresented)
            .onHover { hovering in
                coordinator.onHover(id: self.id, isHovering: hovering)
            }
            .popover(isPresented: $isPresented, arrowEdge: .leading) {
                detailView
                    .background(popoverWindowConfigurator)
                    .onHover { hovering in
                        coordinator.onHover(id: self.id, isHovering: hovering)
                    }
                    .padding(12)
                    .frame(width: 600)
            }
            .onReceive(coordinator.$visibleID) { visibleID in
                let shouldShow = visibleID == self.id
                if isPresented != shouldShow {
                    AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.statusPresentation, preference: motionPreference)) {
                        isPresented = shouldShow
                    }
                }
            }
            .onChange(of: isPresented) { newValue in
                // macOS 13 的 `onChange(of:)` 单参数版拿不到旧值，这里用
                // @State 快照保留上一帧的值，以维持「值确实变化才继续」的语义。
                let oldValue = previousPresentedValue
                previousPresentedValue = newValue
                guard oldValue != newValue else { return }

                if !newValue && coordinator.visibleID == self.id {
                    coordinator.close(id: self.id)
                }
            }
    }

    private func background(isHovering: Bool) -> some View {
        ZStack {
            if isHovering {
                Rectangle()
                    .fill(selectedBackgroundColor)
            } else {
                EmptyView()
            }
        }
    }

    /// 选中态背景色：macOS 用 `selectedContentBackgroundColor`，
    /// UIKit 家族用 `secondarySystemFill` 保持等价观感。
    private var selectedBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .selectedContentBackgroundColor).opacity(0.2)
        #else
        return Color.lumiTertiaryFill
        #endif
    }

    /// popover 窗口配置。
    ///
    /// macOS 需要把 popover 窗口设为「可加入所有 Space」且「全屏时仍显示」，
    /// 否则在多桌面或全屏场景下 popover 会消失。UIKit 家族没有对应的
    /// AppKit 窗口概念，用空实现占位。
    @ViewBuilder
    private var popoverWindowConfigurator: some View {
        #if os(macOS)
        SpaceAwarePopoverWindowConfigurator()
        #else
        Color.clear
        #endif
    }
}

#if os(macOS)
private struct SpaceAwarePopoverWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfigView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ConfigView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }
}
#endif

// MARK: - Sidebar Toolbar Hover Container

/// 右侧栏底部工具栏 Hover 容器
///
/// 为右侧栏底部工具栏的按钮提供统一的 hover 效果。
/// 当鼠标悬停时显示背景色变化，点击时可触发 popover 或执行操作。
///
/// ## 使用示例
///
/// ```swift
/// SidebarToolbarHoverContainer(
///     id: "my-button",
///     tooltip: "Click me"
/// ) {
///     Image(systemName: "star")
/// }
/// ```
///
/// 或者带 popover：
///
/// ```swift
/// SidebarToolbarHoverContainer(
///     detailView: MyDetailView(),
///     id: "my-button"
/// ) {
///     Image(systemName: "star")
/// }
/// ```
public struct SidebarToolbarHoverContainer<Content: View, Detail: View>: View {
    let content: Content
    let detailView: Detail?
    let id: String
    let tooltip: String?
    let cornerRadius: CGFloat

    @ObservedObject private var coordinator = HoverCoordinator.shared
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference
    @State private var isPresented = false
    @State private var isHovering = false

    /// 创建带 popover 的 hover 容器
    ///
    /// - Parameters:
    ///   - detailView: 点击后显示的 popover 内容视图
    ///   - id: 唯一标识符，用于 HoverCoordinator 管理
    ///   - cornerRadius: 圆角半径，默认为 6
    ///   - tooltip: 悬停时显示的提示文本（仅在无 detailView 时生效）
    ///   - content: 容器内容视图
    public init(
        detailView: Detail,
        id: String = UUID().uuidString,
        cornerRadius: CGFloat = 6,
        tooltip: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.detailView = detailView
        self.id = id
        self.cornerRadius = cornerRadius
        self.tooltip = tooltip
        self.content = content()
    }

    /// 创建无 popover 的 hover 容器
    ///
    /// - Parameters:
    ///   - id: 唯一标识符，用于 HoverCoordinator 管理
    ///   - cornerRadius: 圆角半径，默认为 6
    ///   - tooltip: 悬停时显示的提示文本
    ///   - content: 容器内容视图
    public init(
        id: String = UUID().uuidString,
        cornerRadius: CGFloat = 6,
        tooltip: String? = nil,
        @ViewBuilder content: () -> Content
    ) where Detail == EmptyView {
        self.detailView = nil
        self.id = id
        self.cornerRadius = cornerRadius
        self.tooltip = tooltip
        self.content = content()
    }

    public var body: some View {
        baseContent
    }

    @ViewBuilder
    private var baseContent: some View {
        let view = content
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(hoverBackground)
            .animation(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference), value: isHovering || isPresented)
            .onHover { hovering in
                AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)) {
                    isHovering = hovering
                }
            }
            .onTapGesture {
                guard detailView != nil else { return }
                clearAppKitFirstResponder()

                AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.statusPresentation, preference: motionPreference)) {
                    if isPresented {
                        isPresented = false
                        coordinator.close(id: self.id)
                    } else {
                        coordinator.closeAll()
                        isPresented = true
                        coordinator.open(id: self.id)
                    }
                }
            }

        if detailView != nil {
            view.popover(isPresented: $isPresented, arrowEdge: .leading) {
                popoverContent
            }
        } else if let tooltip {
            view.help(tooltip)
        } else {
            view
        }
    }

    private var hoverBackground: some View {
        ZStack {
            if isHovering || isPresented {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(hoverBackgroundColor)
                    .transition(.opacity)
            }
        }
    }

    private var hoverBackgroundColor: Color {
        if isPresented {
            return theme.primary.opacity(0.14)
        }
        return theme.textPrimary.opacity(0.08)
    }

    @ViewBuilder
    private var popoverContent: some View {
        if let detailView {
            detailView
                .onHover { hovering in
                    if hovering {
                        coordinator.open(id: self.id)
                    }
                }
        }
    }
}

@MainActor
private func clearAppKitFirstResponder() {
    #if os(macOS)
    NSApp.keyWindow?.makeFirstResponder(nil)
    NSApp.mainWindow?.makeFirstResponder(nil)
    #endif
}

// MARK: - Sidebar Toolbar Hover Container Extensions

/// 创建简单的 hover 按钮（无 popover）
///
/// - Parameters:
///   - id: 唯一标识符
///   - tooltip: 悬停提示
///   - action: 点击动作
///   - content: 内容视图
@MainActor
@ViewBuilder
public func sidebarToolbarButton<Content: View>(
    id: String = UUID().uuidString,
    tooltip: String? = nil,
    action: @escaping () -> Void,
    @ViewBuilder content: () -> Content
) -> some View {
    SidebarToolbarHoverContainer(id: id, tooltip: tooltip) {
        Button(action: action) {
            content()
        }
        .buttonStyle(.plain)
    }
}

/// 创建带 popover 的 hover 按钮
///
/// - Parameters:
///   - detailView: popover 内容
///   - id: 唯一标识符
///   - content: 内容视图
@MainActor
@ViewBuilder
public func sidebarToolbarPopover<Content: View, Detail: View>(
    detailView: Detail,
    id: String = UUID().uuidString,
    @ViewBuilder content: () -> Content
) -> some View {
    SidebarToolbarHoverContainer(detailView: detailView, id: id) {
        content()
    }
}
