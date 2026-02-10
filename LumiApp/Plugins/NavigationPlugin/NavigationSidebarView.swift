import SwiftUI

/// Navigation Sidebar View: Provides main navigation buttons
struct NavigationSidebarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Title Area
            VStack(alignment: .leading, spacing: 8) {
                Text("Lumi")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                Divider()
            }

            // Navigation List
            List {
                Section(header: Text("Navigation")) {
                    Button(action: {
                        // Home shows detail view, specific actions can be triggered here
                    }) {
                        Label("Home", systemImage: .iconHome)
                    }

                    Button(action: {
                        NotificationCenter.postOpenSettings()
                    }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
    }
}

// MARK: - Preview

#Preview("Navigation Sidebar View") {
    NavigationSidebarView()
        .inRootView()
        .frame(width: 200, height: 600)
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
