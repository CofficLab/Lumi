import SwiftUI

/// `ToolbarProviding` 的默认实现：持有注入的 `ToolbarItem`，
/// 并按 `placement`（leading / center / trailing）渲染为 44pt 高的工具栏。
///
/// 骨架阶段使用：渲染逻辑最简单（无拖拽区、无主题定制），
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

    var body: some View {
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
        .padding(.horizontal, 12)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private func group(_ items: [ToolbarItem]) -> some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                item.makeView()
                    .help(item.title)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
