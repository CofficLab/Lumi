import SwiftUI

/// `RailViewProviding` 的默认实现：持有注入的 `RailTabItem`，
/// 渲染为「顶部标签栏 + 内容区」的侧边栏（类似 Lumi 的 RailView）。
///
/// 骨架阶段使用：点击 tab 切换选中项并展示对应内容，无主题定制；
/// 宿主可注入自己的实现（如基于 PanelRailTabItem 的完整 Rail）。
@MainActor
public final class DefaultRailViewProviding: RailViewProviding, ObservableObject {
    @Published public private(set) var tabs: [RailTabItem] = []

    /// 当前活跃 tab 的 id。
    @Published public private(set) var activeTabID: String?

    public init() {}

    public func registerTabs(_ tabs: [RailTabItem]) {
        self.tabs = tabs.sorted { $0.order < $1.order }
        // 保持当前选中；若为空则默认选中第一个。
        if activeTabID == nil || !self.tabs.contains(where: { $0.id == activeTabID }) {
            activeTabID = self.tabs.first?.id
        }
    }

    /// 选中指定 tab。
    public func selectTab(id: String?) {
        activeTabID = id
    }

    public func makeRailView() -> AnyView {
        AnyView(RailView(provider: self))
    }
}

/// 渲染「标签栏 + 内容区」的 Rail 视图。
private struct RailView: View {
    @ObservedObject var provider: DefaultRailViewProviding
    @State private var activeID: String?

    init(provider: DefaultRailViewProviding) {
        self.provider = provider
        _activeID = State(initialValue: provider.activeTabID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏：仅在多于一个 tab 时显示。
            if provider.tabs.count > 1 {
                HStack(spacing: 4) {
                    ForEach(provider.tabs) { tab in
                        tabButton(tab)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(Color.primary.opacity(0.03))
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }

            // 内容区：显示当前活跃 tab 的内容。
            Group {
                if let active = provider.tabs.first(where: { $0.id == activeID ?? provider.activeTabID }) {
                    active.makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No tab selected")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.015))
    }

    private func tabButton(_ tab: RailTabItem) -> some View {
        let isActive = (activeID ?? provider.activeTabID) == tab.id
        return Button {
            activeID = tab.id
            provider.selectTab(id: tab.id)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13))
                Text(tab.title)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }
}
