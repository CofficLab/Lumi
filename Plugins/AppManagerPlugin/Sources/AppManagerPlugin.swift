import AppKit
import LumiCoreKit
import LumiUI
import SwiftUI

public enum AppManagerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .system
    public static let iconName = "apps.ipad"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-manager",
        displayName: "App Manager",
        description: "Browse installed macOS applications.",
        order: 42
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                AppManagerView()
            }
        ]
    }
}

private struct AppManagerView: View {
    @LumiTheme private var theme
    @State private var apps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private var filteredApps: [InstalledApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(query)
                || app.bundleIdentifier.localizedCaseInsensitiveContains(query)
                || app.path.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppSearchBar(text: $searchText, placeholder: "搜索应用")
                    .frame(maxWidth: 360)

                Text("\(filteredApps.count) / \(apps.count) apps")
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                    loadApps()
                }
                .disabled(isLoading)
            }
            .padding(16)
            .background(theme.appToolbarBackground)

            Divider()

            if isLoading && apps.isEmpty {
                AppLoadingOverlay(message: "Loading Applications", size: .medium)
            } else if filteredApps.isEmpty {
                AppEmptyState(
                    icon: "apps.ipad",
                    title: "No Applications",
                    description: "No installed applications matched the current filter."
                )
            } else {
                List(filteredApps) { app in
                    InstalledAppRow(app: app)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(theme.appWindowBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if apps.isEmpty {
                loadApps()
            }
        }
    }

    private func loadApps() {
        isLoading = true
        Task.detached {
            let loaded = InstalledAppScanner.scan()
            await MainActor.run {
                self.apps = loaded
                self.isLoading = false
            }
        }
    }
}

private struct InstalledAppRow: View {
    @LumiTheme private var theme
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.appBodyEmphasized)
                    .foregroundStyle(theme.textPrimary)

                Text(app.bundleIdentifier.isEmpty ? app.path : app.bundleIdentifier)
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(app.path)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: 340, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appSurface(style: .listRow, cornerRadius: 8)
    }
}

private struct InstalledApp: Identifiable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let path: String
}

private enum InstalledAppScanner {
    static func scan() -> [InstalledApp] {
        let applicationDirectories = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath
        ]

        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for directory in applicationDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: directory),
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                let path = url.path
                guard seen.insert(path).inserted else { continue }
                let bundle = Bundle(url: url)
                apps.append(
                    InstalledApp(
                        id: path,
                        name: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                            ?? url.deletingPathExtension().lastPathComponent,
                        bundleIdentifier: bundle?.bundleIdentifier ?? "",
                        path: path
                    )
                )
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
