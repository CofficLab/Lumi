import LumiUI
import ProviderToolbar
import SwiftUI

/// 按 `placement`（leading / center / trailing）渲染工具栏项的视图。
///
/// 本插件**完全自实现**，不依赖 `ProviderToolbar.DefaultToolbarProviding`
/// 私有的内置渲染；布局常量与默认实现保持一致，保证替换前后视觉零差异：
/// - 高度 44pt，左侧红绿灯预留 76pt；
/// - 整条工具栏可作为窗口拖拽区（macOS）；
/// - center 项绝对居中（`maxWidth 420` + 水平 padding 88），
///   不被 leading / trailing 内容位置影响；
/// - 背景 `AppToolbarContainer(style: .toolbar)`、前景 `theme.textPrimary`。
///
/// 渲染来源为 `displayableToolbarItems`：已分类过滤，并排除已禁用插件的贡献。
internal struct ToolbarView: View {
    @LumiTheme private var theme

    private let provider: ToolbarProvider
    @State private var observationRevision = 0
    @State private var observerHandle: (any ToolbarObserverHandle)?

    private let height: CGFloat = 44
    private let trafficLightReserveWidth: CGFloat = 76

    init(provider: ToolbarProvider) {
        self.provider = provider
    }

    var body: some View {
        // 用 displayableToolbarItems 而非 visibleToolbarItems：在分类过滤之外，
        // 还要排除已禁用插件的贡献，避免其视图残留在工具栏上。
        let items = provider.displayableToolbarItems
        let leading = items.filter { $0.placement == .leading }
        let center = items.filter { $0.placement == .center }
        let trailing = items.filter { $0.placement == .trailing }

        AppToolbarContainer(
            height: height,
            backgroundStyle: .toolbar,
            padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        ) {
            ZStack {
                #if os(macOS)
                WindowDragRegion()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                #endif

                HStack(spacing: 8) {
                    // 红绿灯预留：hiddenTitleBar 下红绿灯悬浮于左上角，
                    // leading 项从此宽度之后开始排布。
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
        .id(observationRevision)
        .foregroundStyle(theme.textPrimary)
        .onAppear {
            guard observerHandle == nil else { return }
            observerHandle = provider.addToolbarObserver { _ in
                observationRevision += 1
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }

    private func group(_ items: [ProviderToolbar.ToolbarItem]) -> some View {
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
