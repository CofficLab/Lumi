import OSLog
import SwiftUI

struct BrewManagerView: View {
    @StateObject private var viewModel = BrewManagerViewModel()
    @State private var selectedTab: BrewTab = .installed

    enum BrewTab: String, CaseIterable, Identifiable {
        case installed = "Installed"
        case updates = "Updates"
        case search = "Search"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .installed: return "list.bullet"
            case .updates: return "arrow.triangle.2.circlepath"
            case .search: return "magnifyingglass"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("View", selection: $selectedTab) {
                ForEach(BrewTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            Group {
                switch selectedTab {
                case .installed:
                    BrewListView(
                        packages: viewModel.installedPackages,
                        emptyMessage: "No packages installed",
                        actionButtonTitle: "Uninstall",
                        actionButtonColor: .red
                    ) { package in
                        Task { await viewModel.uninstall(package: package) }
                    }

                case .updates:
                    VStack {
                        if !viewModel.outdatedPackages.isEmpty {
                            HStack {
                                Spacer()
                                Button("Update All") {
                                    Task { await viewModel.upgradeAll() }
                                }
                                .padding()
                            }
                        }

                        BrewListView(
                            packages: viewModel.outdatedPackages,
                            emptyMessage: "All packages are up to date",
                            actionButtonTitle: "Update",
                            actionButtonColor: .blue
                        ) { package in
                            Task { await viewModel.upgrade(package: package) }
                        }
                    }

                case .search:
                    VStack {
                        HStack {
                            TextField("Search Homebrew packages...", text: $viewModel.searchText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    viewModel.performSearch()
                                }

                            if viewModel.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .padding(.horizontal)

                        BrewListView(
                            packages: viewModel.searchResults,
                            emptyMessage: viewModel.searchText.isEmpty ? "Enter keywords to start searching" : "No related packages found",
                            actionButtonTitle: "Install",
                            actionButtonColor: .green,
                            showInstalledStatus: true
                        ) { package in
                            // 如果已安装则不显示安装按钮，或者显示为卸载/更新
                            // 这里简化逻辑，只处理安装
                            Task { await viewModel.install(package: package) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if viewModel.isLoading && selectedTab != .search {
                ProgressView("Processing...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }
}

struct BrewListView: View {
    let packages: [BrewPackage]
    let emptyMessage: String
    let actionButtonTitle: String
    let actionButtonColor: Color
    var showInstalledStatus: Bool = false
    let action: (BrewPackage) -> Void

    var body: some View {
        if packages.isEmpty {
            VStack {
                Spacer()
                Text(emptyMessage)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List(packages) { package in
                BrewPackageRow(
                    package: package,
                    actionButtonTitle: actionButtonTitle,
                    actionButtonColor: actionButtonColor,
                    showInstalledStatus: showInstalledStatus,
                    action: { action(package) }
                )
            }
        }
    }
}

struct BrewPackageRow: View {
    let package: BrewPackage
    let actionButtonTitle: String
    let actionButtonColor: Color
    let showInstalledStatus: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(package.name)
                        .font(.headline)

                    if package.isCask {
                        Text("Cask")
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    if showInstalledStatus {
                        if package.installedVersion != nil {
                            Text("Installed")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                if let desc = package.desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text("Version: \(package.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let installedVer = package.installedVersion, installedVer != package.version {
                        Text("Installed: \(installedVer)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if showInstalledStatus && package.installedVersion != nil {
                // 如果是搜索结果且已安装，显示已安装状态，不显示操作按钮
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(action: action) {
                    Text(actionButtonTitle)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.bordered)
                .tint(actionButtonColor)
            }
        }
        .padding(.vertical, 4)
    }
}
