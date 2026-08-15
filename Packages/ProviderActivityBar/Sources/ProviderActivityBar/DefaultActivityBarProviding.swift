import SwiftUI

/// `ActivityBarProviding` 的默认实现：持有注入的 `ActivityBarItem`，
/// 渲染为 48pt 宽的竖直入口栏（类似 Lumi 的 ActivityBar）。
///
/// 骨架阶段使用：无高亮/切换容器逻辑，仅展示注入的图标入口；
/// 宿主可注入自己的实现（如基于 ViewContainerItem 的完整 ActivityBar）。
@MainActor
public final class DefaultActivityBarProviding: ActivityBarProviding {
    public private(set) var items: [ActivityBarItem] = []

    public init() {}

    public func registerItems(_ items: [ActivityBarItem]) {
        self.items = items.sorted { $0.order < $1.order }
    }

    public func makeActivityBarView() -> AnyView {
        AnyView(ActivityBarView(items: items))
    }
}

/// 竖直渲染 ActivityBar 项的视图。
private struct ActivityBarView: View {
    let items: [ActivityBarItem]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(items) { item in
                Button(action: {}) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 15))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.title)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.03))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 1)
        }
    }
}
