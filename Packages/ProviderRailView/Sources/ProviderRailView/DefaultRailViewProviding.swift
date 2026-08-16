import SwiftUI

/// `RailViewProviding` 的默认实现：持有注入的 `RailTabItem`，
/// 渲染为「顶部标签栏 + 内容区」的侧边栏（类似 Lumi 的 RailView）。
///
/// 骨架阶段使用：点击 tab 切换选中项并展示对应内容，无主题定制；
/// 宿主可注入自己的实现（如基于 PanelRailTabItem 的完整 Rail）。
@MainActor
public final class DefaultRailViewProviding: RailViewProviding, ObservableObject {
    @Published public private(set) var tabs: [RailTabItem] = []
    @Published public private(set) var activeGroupID: String?
    @Published public private(set) var activeTabID: String?

    /// 记住每个分组最后一次选中的标签。
    private var rememberedTabIDs: [String: String] = [:]

    public init() {}

    public func registerTabs(_ tabs: [RailTabItem]) {
        self.tabs = tabs.sorted { $0.order < $1.order }
        reconcileActiveTab()
    }

    public func activateGroup(id: String?) {
        guard activeGroupID != id else {
            reconcileActiveTab()
            return
        }
        rememberActiveTab()
        activeGroupID = id
        reconcileActiveTab()
    }

    public func activateTab(id: String?) {
        guard let groupID = activeGroupID else {
            activeTabID = nil
            return
        }
        guard let id else {
            activeTabID = nil
            rememberedTabIDs[groupID] = nil
            return
        }
        guard visibleTabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        rememberedTabIDs[groupID] = id
    }

    public func makeRailView() -> AnyView {
        AnyView(RailView(provider: self))
    }

    fileprivate var visibleTabs: [RailTabItem] {
        guard let activeGroupID else { return [] }
        return tabs.filter { $0.groupID == activeGroupID }
    }

    private func rememberActiveTab() {
        guard let groupID = activeGroupID, let activeTabID else { return }
        rememberedTabIDs[groupID] = activeTabID
    }

    private func reconcileActiveTab() {
        let candidates = visibleTabs
        guard let groupID = activeGroupID, !candidates.isEmpty else {
            activeTabID = nil
            return
        }
        if let activeTabID, candidates.contains(where: { $0.id == activeTabID }) {
            rememberedTabIDs[groupID] = activeTabID
            return
        }
        if let remembered = rememberedTabIDs[groupID],
           candidates.contains(where: { $0.id == remembered }) {
            activeTabID = remembered
        } else {
            activeTabID = candidates[0].id
        }
        rememberedTabIDs[groupID] = activeTabID
    }
}

/// 渲染「标签栏 + 内容区」的 Rail 视图。
private struct RailView: View {
    @ObservedObject var provider: DefaultRailViewProviding

    var body: some View {
        Group {
            if !provider.visibleTabs.isEmpty {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // 标签栏：仅在当前分组多于一个 tab 时显示。
                        if provider.visibleTabs.count > 1 {
                            HStack(spacing: 4) {
                                ForEach(provider.visibleTabs) { tab in
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

                        if let active = provider.visibleTabs.first(where: { $0.id == provider.activeTabID }) {
                            active.makeView()
                                .id(active.id)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(minWidth: 200, idealWidth: 228, maxWidth: 360, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.015))

                    Divider()
                }
            }
        }
    }

    private func tabButton(_ tab: RailTabItem) -> some View {
        let isActive = provider.activeTabID == tab.id
        return Button {
            provider.activateTab(id: tab.id)
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
