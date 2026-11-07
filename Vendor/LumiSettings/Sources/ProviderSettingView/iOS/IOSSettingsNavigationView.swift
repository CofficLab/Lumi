#if os(iOS)
import LumiUI
import SwiftUI

/// Shared iOS settings navigation content.
///
/// The host app owns the window or sheet that presents this view.
@MainActor
public struct IOSSettingsNavigationView<Provider: SettingViewProviding>: View {
    let provider: Provider
    /// 是否在导航栏显示「完成」按钮。sheet 呈现时需要；push 进宿主导航栈时不需要。
    let showsDoneButton: Bool
    @State private var path: [String] = []
    @State private var observationRevision = 0
    @State private var observerHandle: (any SettingViewObserverHandle)?

    public init(provider: Provider, showsDoneButton: Bool = false) {
        self.provider = provider
        self.showsDoneButton = showsDoneButton
    }

    public var body: some View {
        NavigationStack(path: $path) {
            IOSSettingsRootList(provider: provider, showsDoneButton: showsDoneButton)
                .onChange(of: path) { newPath in
                    provider.selectEntry(id: newPath.last)
                }
        }
        .onChange(of: observationRevision) { _ in }
        .onAppear {
            guard observerHandle == nil else { return }
            observerHandle = provider.addSettingViewObserver { _ in
                observationRevision += 1
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }
}

/// iOS 设置根页：分组列表 + 搜索。
///
/// - 分组：入口按 `SettingEntryItem.group` 分组，未声明分组的入口归入末尾的无标题分组；
/// - 搜索：`.searchable` 放在导航栏，与 Settings.app 一致；
/// - 行：仅文字 + 箭头（iOS Settings 根页不画前置图标）。
///
/// 该视图**不自带** `NavigationStack`：可以直接 push 进宿主 App 自己的导航栈，
/// 也可被 `IOSSettingsNavigationView` 包一层独立栈使用。
@MainActor
public struct IOSSettingsRootList<Provider: SettingViewProviding>: View {
    let provider: Provider
    /// 是否在导航栏显示「完成」按钮。sheet 呈现时需要；push 进宿主导航栈时不需要。
    let showsDoneButton: Bool
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    public init(provider: Provider, showsDoneButton: Bool = false) {
        self.provider = provider
        self.showsDoneButton = showsDoneButton
    }

    public var body: some View {
        List {
            ForEach(cards) { card in
                if let title = card.title {
                    Section {
                        entryRows(card.entries)
                    } header: {
                        Text(title)
                    }
                } else {
                    Section {
                        entryRows(card.entries)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(LumiUILocalization.string("Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: LumiUILocalization.string("Search"))
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LumiUILocalization.string("Done")) {
                        dismiss()
                    }
                }
            }
        }
        .navigationDestination(for: SettingEntryRoute.self) { route in
            destination(for: route)
        }
    }

    @ViewBuilder
    private func entryRows(_ entries: [SettingEntryItem]) -> some View {
        ForEach(entries) { entry in
            NavigationLink(value: SettingEntryRoute(entryID: entry.id)) {
                Text(entry.title)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: SettingEntryRoute) -> some View {
        if let entry = provider.entries.first(where: { $0.id == route.entryID }) {
            entry.makeDetailView()
                .navigationTitle(entry.title)
                .navigationBarTitleDisplayMode(.inline)
        } else {
            AppEmptyState(
                icon: "gearshape",
                title: LumiUILocalization.string("Setting unavailable")
            )
        }
    }

    // MARK: - Sections

    /// 过滤后的入口分组（已把连续的无标题分组合并成一张卡片）。
    private var cards: [SettingEntryGrouping.Card] {
        SettingEntryGrouping.cards(from: provider.entries, keyword: searchText)
    }
}

#endif
