import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct SettingsView: View {
    @LumiTheme private var theme
    let pluginService: PluginService
    let lumiUIService: LumiUIService
    @ObservedObject var chatService: ChatService
    @State private var selectedTab: SettingsTab = .general

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
    }

    private var sidebar: some View {
        AppSettingsSidebarContainer(width: 220) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsSidebarHeaderView()

                AppSettingsDivider()

                VStack(spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        AppSettingsSidebarItem(
                            title: tab.title,
                            systemImage: tab.systemImage,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
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
        case .general:
            GeneralSettingsPage()
        case .appearance:
            AppearanceSettingsPage(lumiUIService: lumiUIService)
        case .localProvider:
            LocalProviderSettingsPage(chatService: chatService)
        case .remoteProvider:
            RemoteProviderSettingsPage(chatService: chatService)
        case .plugins:
            PluginSettingsPage(pluginService: pluginService, chatService: chatService)
        case .about:
            AboutPage()
        }
    }
}
