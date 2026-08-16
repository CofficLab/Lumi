import SwiftUI

/// `ActivityBarProviding` 的默认实现：持有注入的 `ActivityBarItem`，
/// 渲染为 48pt 宽的竖直入口栏（类似 Lumi 的 ActivityBar）。
///
@MainActor
public final class DefaultActivityBarProviding: ActivityBarProviding, ObservableObject {
    @Published public private(set) var items: [ActivityBarItem] = []
    @Published public private(set) var activeItemID: String?

    public init() {}

    public func registerItems(_ items: [ActivityBarItem]) {
        self.items = items.sorted { $0.order < $1.order }
        let nextActiveID: String?
        if let activeItemID, self.items.contains(where: { $0.id == activeItemID }) {
            nextActiveID = activeItemID
        } else {
            nextActiveID = self.items.first?.id
        }
        setActiveItemID(nextActiveID)
    }

    public func activateItem(id: String?) {
        guard id == nil || items.contains(where: { $0.id == id }) else { return }
        setActiveItemID(id)
    }

    public func makeActivityBarView() -> AnyView {
        AnyView(ActivityBarView(provider: self))
    }

    private func setActiveItemID(_ id: String?) {
        guard activeItemID != id else { return }
        activeItemID = id
        for item in items {
            item.onActiveItemChanged(id)
        }
    }
}

/// 竖直渲染 ActivityBar 项的视图。
private struct ActivityBarView: View {
    @ObservedObject var provider: DefaultActivityBarProviding

    var body: some View {
        VStack(spacing: 6) {
            ForEach(provider.items) { item in
                Button {
                    provider.activateItem(id: item.id)
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 15))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(provider.activeItemID == item.id
                                    ? Color.accentColor.opacity(0.16)
                                    : Color.clear)
                        )
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
