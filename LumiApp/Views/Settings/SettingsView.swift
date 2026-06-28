import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// Represents a selectable settings tab — either a core built-in tab or a plugin-registered tab.
enum SettingsTabSelection: Identifiable, Equatable {
    case core(SettingsTab)
    case plugin(id: String, title: String, systemImage: String, content: @MainActor () -> AnyView)

    var id: String {
        switch self {
        case .core(let tab): return "core.\(tab.rawValue)"
        case .plugin(let id, _, _, _): return "plugin.\(id)"
        }
    }

    var title: String {
        switch self {
        case .core(let tab): return tab.title
        case .plugin(_, let title, _, _): return title
        }
    }

    var systemImage: String {
        switch self {
        case .core(let tab): return tab.systemImage
        case .plugin(_, _, let image, _): return image
        }
    }

    static func == (lhs: SettingsTabSelection, rhs: SettingsTabSelection) -> Bool {
        lhs.id == rhs.id
    }
}

/// A sidebar row that may also be a visual separator.
enum SettingsSidebarItem: Identifiable {
    case selectable(SettingsTabSelection)
    case separator

    var id: String {
        switch self {
        case .selectable(let s): return s.id
        case .separator: return "separator"
        }
    }
}

struct SettingsView: View {
    @LumiTheme private var theme
    let pluginService: PluginService
    let lumiUIService: LumiUIService
    @ObservedObject var chatService: ChatService
    @State private var selectedTab: SettingsTabSelection?

    /// All plugin-registered settings tabs, aggregated from every loaded plugin.
    private var pluginTabs: [LumiSettingsTabItem] {
        var tabs: [LumiSettingsTabItem] = []
        let context = LumiPluginContext(
            activeSectionID: "settings",
            activeSectionTitle: "设置",
            dependencies: {
                var deps = LumiPluginDependencies()
                deps.register((any HistoryQueryService).self, chatService)
                return deps
            }()
        )
        for plugin in pluginService.plugins {
            tabs.append(contentsOf: plugin.addSettingsTabs(context: context))
        }
        return tabs
    }

    /// Combined list of sidebar items: core tabs followed by plugin tabs with a separator.
    private var sidebarItems: [SettingsSidebarItem] {
        var items: [SettingsSidebarItem] = SettingsTab.allCases.map { .selectable(.core($0)) }
        if !pluginTabs.isEmpty {
            items.append(.separator)
            for tab in pluginTabs {
                let content = tab.makeContent()
                items.append(.selectable(.plugin(
                    id: tab.id,
                    title: tab.title,
                    systemImage: tab.systemImage,
                    content: { content }
                )))
            }
        }
        return items
    }

    var body: some View {
        AppSettingsSidebarShell {
            sidebar
        } detail: {
            AppSettingsDetailPane {
                detail
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(theme.background)
        .ignoresSafeArea()
        .onAppear {
            if selectedTab == nil {
                selectedTab = .core(.general)
            }
        }
        .onChange(of: selectableIDs) { _, newIDs in
            guard let current = selectedTab,
                  newIDs.contains(current.id)
            else {
                selectedTab = .core(.general)
                return
            }
        }
    }

    /// Helper: all selectable IDs for stale-state validation.
    private var selectableIDs: [String] {
        sidebarItems.compactMap { item in
            if case .selectable(let s) = item { return s.id }
            return nil
        }
    }

    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSidebarHeaderView()

                AppSettingsDivider()

                VStack(spacing: 6) {
                    ForEach(sidebarItems) { item in
                        switch item {
                        case .separator:
                            AppSettingsDivider()
                        case .selectable(let selection):
                            AppSettingsSidebarItem(
                                title: selection.title,
                                systemImage: selection.systemImage,
                                isSelected: selectedTab == selection
                            ) {
                                selectedTab = selection
                            }
                        }
                    }
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedTab {
        case .core(.general):
            GeneralSettingsPage()
        case .core(.appearance):
            AppearanceSettingsPage(lumiUIService: lumiUIService)
        case .core(.localProvider):
            LocalProviderSettingsPage(chatService: chatService)
        case .core(.remoteProvider):
            RemoteProviderSettingsPage(chatService: chatService)
        case .core(.plugins):
            PluginSettingsPage(pluginService: pluginService, chatService: chatService)
        case .core(.about):
            AboutPage()
        case .plugin(_, _, _, let content):
            content()
        case nil:
            GeneralSettingsPage()
        }
    }
}
