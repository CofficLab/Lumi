import Combine
import LumiUI
import SwiftUI

/// `StatusBarProviding` 的默认实现：持有注入的 `StatusBarItem`，
/// 并按 `placement`（leading / center / trailing）渲染为 28pt 高的状态栏。
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
        let items = provider.visibleStatusBarItems
        let leading = items.filter { $0.placement == .leading }
        let center = items.filter { $0.placement == .center }
        let trailing = items.filter { $0.placement == .trailing }

        HStack(spacing: 8) {
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
