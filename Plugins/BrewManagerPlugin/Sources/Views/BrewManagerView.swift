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
        VStack(spacing: 0) {
            // Tab Picker
            AppCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                Picker("View", selection: $selectedTab) {
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
                switch selectedTab {
                case .installed:
                    BrewListView(
                        packages: viewModel.installedPackages,
                        emptyMessage: LumiPluginLocalization.string("No packages installed", bundle: .module),
                        actionButtonTitle: LumiPluginLocalization.string("Uninstall", bundle: .module),
                        actionButtonColor: Color(hex: "FF453A")
                    ) { package in
                        Task { await viewModel.uninstall(package: package) }
                    }

                case .updates:
                    VStack {
                        if !viewModel.outdatedPackages.isEmpty {
                            HStack {
                                Spacer()
                                AppButton(LocalizedStringKey("Update All"), style: .primary, fillsWidth: true, action: { Task { await viewModel.upgradeAll() } })
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
                                    title: LocalizedStringKey("Search"),
                                    text: $viewModel.searchText,
                                    placeholder: LocalizedStringKey("Search Homebrew packages...")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if viewModel.isLoading && selectedTab != .search {
                ProgressView(LumiPluginLocalization.string("Processing...", bundle: .module))
                    .padding()
                    .background(Material.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .alert(LumiPluginLocalization.string("Error", bundle: .module), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(LumiPluginLocalization.string("OK", bundle: .module), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                AppButton(LocalizedStringKey("Refresh"), style: .secondary, fillsWidth: true, action: { Task { await viewModel.refresh() } })
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
                                Text("Installed", tableName: "BrewManager")
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
                    AppButton(LocalizedStringKey(actionButtonTitle), style: .secondary, size: .small, action: action)
                        .foregroundColor(actionButtonColor)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
