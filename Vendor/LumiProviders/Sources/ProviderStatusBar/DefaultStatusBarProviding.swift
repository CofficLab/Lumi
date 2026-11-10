import Combine
import LumiUI
import SwiftUI

/// `StatusBarProviding` 的默认实现：持有注入的 `StatusBarItem`，
/// 并按 `placement`（leading / center / trailing）渲染为 28pt 高的状态栏。
///
/// 没有任何贡献项时整条状态栏不渲染（不占高度，也不留背景、分隔线或点击区域）；
/// 贡献项在有贡献后增删会驱动视图重新计算可见性。
///
/// 视觉与旧版 GitOK 状态栏对齐：
/// - 高度 28pt，三段式布局（leading / center / trailing，段间 Spacer）；
/// - 背景使用 `theme.surface`，顶部 1px 主题分隔线；
/// - 前景 `theme.statusBarItemForeground`。
@MainActor
public final class DefaultStatusBarProviding: StatusBarProviding, ObservableObject {
    @Published public private(set) var statusBarItems: [StatusBarItem] = []

    public init() {}

    public func registerStatusBarItems(_ items: [StatusBarItem]) {
        statusBarItems = items
    }

    public func makeStatusBarView() -> AnyView {
        AnyView(StatusBarView(provider: self))
    }

    public var visibleStatusBarItems: [StatusBarItem] {
        statusBarItems
    }
}

/// 按 placement 渲染状态栏项的视图。
private struct StatusBarView: View {
    @LumiTheme private var theme

    @ObservedObject var provider: DefaultStatusBarProviding

    private let height: CGFloat = 28

    var body: some View {
        if provider.hasVisibleStatusBarItems {
            barContent
        } else {
            EmptyView()
        }
    }

    private var barContent: some View {
        let items = provider.visibleStatusBarItems
        let leading = items.filter { $0.placement == .leading }
        let center = items.filter { $0.placement == .center }
        let trailing = items.filter { $0.placement == .trailing }

        return HStack(spacing: 8) {
            group(leading)

            Spacer(minLength: 12)

            group(center)

            Spacer(minLength: 12)

            group(trailing)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            theme.surface.opacity(0.96)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
        }
        .foregroundStyle(theme.statusBarItemForeground)
    }

    private func group(_ items: [StatusBarItem]) -> some View {
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
