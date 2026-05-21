import SwiftUI
import LumiUI

struct MenuBarSettingsView: View {
    @StateObject private var service = MenuBarManagerService.shared
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(String(localized: "Menu Bar Manager", table: "MenuBarManager"))
                            .font(.system(size: 15, weight: .medium))
                        Text(String(localized: "Manage your menu bar items", table: "MenuBarManager"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    if !service.isPermissionGranted {
                        AppButton(
                            String(localized: "Grant Permission", table: "MenuBarManager"),
                            systemImage: "lock.open",
                            style: .primary
                        ) {
                            service.requestPermission()
                        }
                    }
                }
                
                GlassDivider()
                
                if service.isPermissionGranted {
                    // Item List
                    ScrollView {
                        LazyVStack(spacing: 12) {
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
                } else {
                    AppEmptyState(
                        icon: "lock.fill",
                        title: LocalizedStringKey(String(localized: "Permission Required", table: "MenuBarManager")),
                        description: LocalizedStringKey(String(localized: "Accessibility permission is required to manage menu bar items.", table: "MenuBarManager"))
                    )
                    .frame(minHeight: 220)
                }
            }
            .padding()
        }
        .padding()
        .onAppear {
            service.startMonitoring()
            service.checkPermission()
        }
    }
}

struct MenuBarItemRow: View {
    let item: MenuBarItem
    let isHidden: Bool
    let onToggle: () -> Void
    
    var body: some View {
        AppListRow {
            HStack(spacing: 10) {
                if let icon = item.icon {
                    AppImageThumbnail(
                        image: Image(nsImage: icon),
                        size: CGSize(width: 16, height: 16),
                        shape: .none
                    )
                } else {
                    Image(systemName: "app.dashed")
                }

                Text(item.name)
                    .font(.body)

                Spacer()

                AppIconButton(
                    systemImage: isHidden ? "eye.slash" : "eye",
                    tint: isHidden ? .secondary : .primary
                ) {
                    onToggle()
                }
            }
        }
    }
}
