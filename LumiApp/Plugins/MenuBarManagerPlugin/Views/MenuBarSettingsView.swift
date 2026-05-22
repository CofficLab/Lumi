import SwiftUI
import LumiUI

struct MenuBarSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var service = MenuBarManagerService.shared

    var body: some View {
        PluginSettingsScaffold(
            String(localized: "Menu Bar Manager", table: "MenuBarManager"),
            subtitle: String(localized: "Manage your menu bar items", table: "MenuBarManager")
        ) {
            if !service.isPermissionGranted {
                AppCard {
                    AppEmptyState(
                        icon: "lock.fill",
                        title: LocalizedStringKey(String(localized: "Permission Required", table: "MenuBarManager")),
                        description: LocalizedStringKey(String(localized: "Accessibility permission is required to manage menu bar items.", table: "MenuBarManager")),
                        actionTitle: LocalizedStringKey(String(localized: "Grant Permission", table: "MenuBarManager")),
                        action: { service.requestPermission() }
                    )
                    .frame(minHeight: 220)
                }
            } else {
                itemsCard
            }
        }
        .onAppear {
            service.startMonitoring()
            service.checkPermission()
        }
    }

    private var itemsCard: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "Menu Bar Items", table: "MenuBarManager"),
                spacing: 8
            ) {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(service.menuBarItems) { item in
                            MenuBarItemRow(item: item, isHidden: service.hiddenItems.contains(item.id)) {
                                service.toggleItemVisibility(id: item.id)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)

                HStack {
                    Spacer()
                    AppButton(
                        String(localized: "Refresh", table: "MenuBarManager"),
                        systemImage: "arrow.clockwise",
                        style: .secondary,
                        size: .small
                    ) {
                        service.refreshMenuBarItems()
                    }
                }
            }
        }
    }
}

struct MenuBarItemRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let item: MenuBarItem
    let isHidden: Bool
    let onToggle: () -> Void

    var body: some View {
        AppSettingsRow(verticalPadding: 6) {
            HStack(spacing: 10) {
                if let icon = item.icon {
                    AppImageThumbnail(
                        image: Image(nsImage: icon),
                        size: CGSize(width: 16, height: 16),
                        shape: .none
                    )
                } else {
                    Image(systemName: "app.dashed")
                        .foregroundColor(theme.textSecondary)
                }

                Text(item.name)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                AppIconButton(
                    systemImage: isHidden ? "eye.slash" : "eye",
                    tint: isHidden ? theme.textSecondary : theme.primary
                ) {
                    onToggle()
                }
            }
        }
    }
}
