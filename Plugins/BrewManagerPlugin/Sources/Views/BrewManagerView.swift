import os
import SwiftUI
import LumiUI
import SuperLogKit
import LumiKernel

struct BrewManagerView: View {
    @StateObject private var viewModel = BrewManagerViewModel()
    @State private var selectedTab: BrewTab = .installed

    enum BrewTab: String, CaseIterable, Identifiable {
        case installed = "Installed"
        case updates = "Updates"
        case search = "Search"

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .installed: return LumiPluginLocalization.string("Installed", bundle: .module)
            case .updates: return LumiPluginLocalization.string("Updates", bundle: .module)
            case .search: return LumiPluginLocalization.string("Search", bundle: .module)
            }
        }

        var icon: String {
            switch self {
            case .installed: return "list.bullet"
            case .updates: return "arrow.triangle.2.circlepath"
            case .search: return "magnifyingglass"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(minWidth: 420, idealWidth: 720, minHeight: 360, idealHeight: 520)
        .overlay {
            if viewModel.isLoading && selectedTab != .search {
                ProgressView(LumiPluginLocalization.string("Processing...", bundle: .module))
                    .padding()
                    .background(Material.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .onReceive(NotificationCenter.default.publisher(for: .brewManagerRefreshRequested)) { _ in
            Task { await viewModel.refresh() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // Tab Picker
            AppCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                Picker(LumiPluginLocalization.string("View", bundle: .module), selection: $selectedTab) {
                    ForEach(BrewTab.allCases) { tab in
                        Label(tab.localizedName, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.top)

            // Content
            Group {
                if let errorMessage = viewModel.errorMessage {
                    BrewManagerErrorView(
                        message: errorMessage,
                        onDismiss: { viewModel.errorMessage = nil },
                        onRetry: { viewModel.errorMessage = nil }
                    )
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
                } else {
                    switch selectedTab {
                    case .installed:
                        BrewInstalledContent(
                            packages: viewModel.installedPackages,
                            isLoading: viewModel.isLoading,
                            onUninstall: { package in
                                Task { await viewModel.uninstall(package: package) }
                            },
                            onBrowseSearch: { selectedTab = .search }
                        )

                    case .updates:
                        VStack {
                            if !viewModel.outdatedPackages.isEmpty {
                                HStack {
                                    Spacer()
                                    AppButton(LumiPluginLocalization.string("Update All", bundle: .module), style: .primary, fillsWidth: true, action: { Task { await viewModel.upgradeAll() } })
                                    .padding()
                                }
                            }

                            BrewListView(
                                packages: viewModel.outdatedPackages,
                                emptyMessage: LumiPluginLocalization.string("All packages are up to date", bundle: .module),
                                actionButtonTitle: LumiPluginLocalization.string("Update", bundle: .module),
                                actionButtonColor: Color(hex: "0A84FF")
                            ) { package in
                                Task { await viewModel.upgrade(package: package) }
                            }
                        }

                    case .search:
                        VStack {
                            AppCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                                HStack {
                                    GlassTextField(
                                        title: LumiPluginLocalization.string("Search", bundle: .module),
                                        text: $viewModel.searchText,
                                        placeholder: LumiPluginLocalization.string("Search Homebrew packages...", bundle: .module)
                                    )
                                    .onSubmit {
                                        viewModel.performSearch()
                                    }

                                    if viewModel.isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            BrewListView(
                                packages: viewModel.searchResults,
                                emptyMessage: viewModel.searchText.isEmpty ? LumiPluginLocalization.string("Enter keywords to start searching", bundle: .module) : LumiPluginLocalization.string("No related packages found", bundle: .module),
                                actionButtonTitle: LumiPluginLocalization.string("Install", bundle: .module),
                                actionButtonColor: Color(hex: "30D158"),
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
        }
    }
}

/// Container for the "Installed" tab.
///
/// Routes to either the rich empty state (`BrewManagerEmptyView`) or the
/// populated list (`BrewListView`). Kept private to this file since it is
/// only used as the `.installed` branch of `BrewManagerView`.
struct BrewInstalledContent: View {
    let packages: [BrewPackage]
    let isLoading: Bool
    let onUninstall: (BrewPackage) -> Void
    let onBrowseSearch: () -> Void

    var body: some View {
        if packages.isEmpty && !isLoading {
            BrewManagerEmptyView(onBrowsePackages: onBrowseSearch)
        } else {
            BrewListView(
                packages: packages,
                emptyMessage: LumiPluginLocalization.string("No packages installed", bundle: .module),
                actionButtonTitle: LumiPluginLocalization.string("Uninstall", bundle: .module),
                actionButtonColor: Color(hex: "FF453A"),
                action: onUninstall
            )
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
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(packages) { package in
                        BrewPackageRow(
                            package: package,
                            actionButtonTitle: actionButtonTitle,
                            actionButtonColor: actionButtonColor,
                            showInstalledStatus: showInstalledStatus,
                            action: { action(package) }
                        )
                    }
                }
                .padding()
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
        AppCard(cornerRadius: 12, padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(package.name)
                            .font(.system(size: 15, weight: .medium))

                        if package.isCask {
                            AppTag(LumiPluginLocalization.string("Cask", bundle: .module), style: .accent)
                        }

                        if showInstalledStatus {
                            if package.installedVersion != nil {
                                Text(LumiPluginLocalization.string("Installed", bundle: .module))
                                    .font(.caption)
                                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00D4FF"), Color(hex: "7C6FFF")], startPoint: .leading, endPoint: .trailing))
                            }
                        }
                    }

                    if let desc = package.desc {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        Text(LumiPluginLocalization.string("Version: \(package.version)", bundle: .module))
                            .font(.caption2)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        if let installedVer = package.installedVersion, installedVer != package.version {
                            Text(LumiPluginLocalization.string("Installed: \(installedVer)", bundle: .module))
                                .font(.caption2)
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        }
                    }
                }

                Spacer()

                if showInstalledStatus && package.installedVersion != nil {
                    // 如果是搜索结果且已安装，显示已安装状态，不显示操作按钮
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "30D158"))
                } else {
                    AppButton(actionButtonTitle, style: .secondary, size: .small, action: action)
                        .foregroundColor(actionButtonColor)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
