import SwiftUI

/// `SettingViewProviding` 的默认实现：持有注入的 `SettingEntryItem`，
/// 渲染为「左侧入口列表 + 右侧详情视图」的设置界面（类似 Lumi 的 SettingsView）。
///
/// 骨架阶段使用：无主题定制，入口为空时显示占位提示；
/// 宿主可注入自己的实现（如基于 SettingsTabItem 的完整设置界面）。
@MainActor
public final class DefaultSettingViewProviding: SettingViewProviding, ObservableObject {
    @Published public private(set) var entries: [SettingEntryItem] = []

    /// 当前选中入口的 id。
    @Published public private(set) var selectedEntryID: String?

    public init() {}

    public func registerEntries(_ entries: [SettingEntryItem]) {
        self.entries = entries.sorted { $0.order < $1.order }
        // 保持当前选中；若为空则默认选中第一个。
        if selectedEntryID == nil || !self.entries.contains(where: { $0.id == selectedEntryID }) {
            selectedEntryID = self.entries.first?.id
        }
    }

    /// 选中指定入口。
    public func selectEntry(id: String?) {
        selectedEntryID = id
    }

    public func makeSettingView() -> AnyView {
        AnyView(SettingView(provider: self))
    }
}

/// 渲染「左侧入口列表 + 右侧详情视图」的设置界面。
private struct SettingView: View {
    @ObservedObject var provider: DefaultSettingViewProviding
    @State private var selectedID: String?

    init(provider: DefaultSettingViewProviding) {
        self.provider = provider
        _selectedID = State(initialValue: provider.selectedEntryID)
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：入口列表
            List {
                ForEach(provider.entries) { entry in
                    Button {
                        selectedID = entry.id
                        provider.selectEntry(id: entry.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: entry.systemImage)
                                .frame(width: 20)
                            Text(entry.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .background(
                            (selectedID ?? provider.selectedEntryID) == entry.id
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 220)

            Divider()

            // 右侧：详情视图
            Group {
                if let selected = provider.entries.first(where: { $0.id == selectedID ?? provider.selectedEntryID }) {
                    selected.makeDetailView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Select a setting")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(24)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
