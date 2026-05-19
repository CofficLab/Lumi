import SwiftUI
import LumiUI
import MagicKit

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
                        Button(String(localized: "Grant Permission", table: "MenuBarManager")) {
                            service.requestPermission()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Divider()
                
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
                        Button(String(localized: "Refresh", table: "MenuBarManager")) {
                            service.refreshMenuBarItems()
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Permission Required",
                        systemImage: "lock.fill",
                        description: Text(String(localized: "Accessibility permission is required to manage menu bar items.", table: "MenuBarManager"))
                    )
                }
            }
            .padding()
        }
        .padding()
        .onAppear {
            service.checkPermission()
        }
    }
}

struct MenuBarItemRow: View {
    let item: MenuBarItem
    let isHidden: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
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
            
            Button(action: onToggle) {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(isHidden ? .secondary : .primary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
