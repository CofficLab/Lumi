import SwiftUI
import MagicKit

struct MenuBarSettingsView: View {
    @StateObject private var service = MenuBarManagerService.shared
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Menu Bar Manager")
                            .font(.headline)
                        Text("Manage your menu bar items")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    if !service.isPermissionGranted {
                        Button("Grant Permission") {
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
                        Button("Refresh") {
                            service.refreshMenuBarItems()
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Permission Required",
                        systemImage: "lock.fill",
                        description: Text("Accessibility permission is required to manage menu bar items.")
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
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
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
