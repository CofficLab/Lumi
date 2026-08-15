import SwiftUI

#if os(macOS)
import AppKit
#endif

/// `ToolbarProviding` 的默认实现：持有注入的 `ToolbarItem`，
/// 并按 `placement`（leading / center / trailing）渲染为 44pt 高的工具栏。
///
/// 尺寸与旧版 Lumi（`FactoryCore.AppTitleToolbar`）保持完全一致：
/// - 高度 44pt，左侧红绿灯预留 76pt（`trafficLightReserveWidth`）；
/// - 整条工具栏可作为窗口拖拽区（macOS）；
/// - center 项绝对居中（`maxWidth 420` + 水平 padding 88），
///   不被 leading / trailing 内容位置影响。
///
/// 宿主可注入自己的实现（如基于 AppTitleToolbar 的完整工具栏）。
@MainActor
public final class DefaultToolbarProviding: ToolbarProviding {
    public private(set) var toolbarItems: [ToolbarItem] = []

    public init() {}

    public func registerToolbarItems(_ items: [ToolbarItem]) {
        toolbarItems = items
    }

    public func makeToolbarView() -> AnyView {
        AnyView(ToolbarView(items: toolbarItems))
    }
}

/// 按 placement 渲染工具栏项的视图。
private struct ToolbarView: View {
    let items: [ToolbarItem]

    /// 与旧版 `AppTitleToolbar` 保持一致的尺寸常量。
    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    var body: some View {
        let leading = items.filter { $0.placement == .leading }
        let center = items.filter { $0.placement == .center }
        let trailing = items.filter { $0.placement == .trailing }

        ZStack {
            #if os(macOS)
            WindowDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            #endif

            HStack(spacing: 8) {
                // 红绿灯预留：hiddenTitleBar 下红绿灯悬浮于左上角，
                // leading 项从此宽度之后开始排布（与旧版完全一致）。
                Color.clear
                    .frame(width: trafficLightReserveWidth, height: height)
                    .accessibilityHidden(true)

                group(leading)

                Spacer(minLength: 12)

                group(trailing)
            }
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // center 项绝对居中，maxWidth 420，并左右留出红绿灯空间。
            group(center)
                .frame(maxWidth: 420)
                .padding(.horizontal, trafficLightReserveWidth + 12)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private func group(_ items: [ToolbarItem]) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                item.makeView()
                    .help(item.title)
            }
        }
        .frame(height: height)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#if os(macOS)
/// 整条工具栏的窗口拖拽区：与旧版 `AppTitleToolbar` 的拖拽行为一致。
private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView {
        DragRegionView()
    }

    func updateNSView(_ nsView: DragRegionView, context: Context) {}
}

private final class DragRegionView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
#endif
