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

        var localizedName: String {
            switch self {
            case .installed: return String(localized: "Installed")
            case .updates: return String(localized: "Updates")
            case .search: return String(localized: "Search")
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
            MystiqueGlassCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
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
                        emptyMessage: String(localized: "No packages installed"),
                        actionButtonTitle: String(localized: "Uninstall"),
                        actionButtonColor: DesignTokens.Color.semantic.error
                    ) { package in
                        Task { await viewModel.uninstall(package: package) }
                    }

                case .updates:
                    VStack {
                        if !viewModel.outdatedPackages.isEmpty {
                            HStack {
                                Spacer()
                                GlassButton(title: LocalizedStringKey("Update All"), style: .primary) {
                                    Task { await viewModel.upgradeAll() }
                                }
                                .padding()
                            }
                        }

                        BrewListView(
                            packages: viewModel.outdatedPackages,
                            emptyMessage: String(localized: "All packages are up to date"),
                            actionButtonTitle: String(localized: "Update"),
                            actionButtonColor: DesignTokens.Color.semantic.info
                        ) { package in
                            Task { await viewModel.upgrade(package: package) }
                        }
                    }

                case .search:
                    VStack {
                        MystiqueGlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                            HStack {
                                GlassTextField(
                                    title: LocalizedStringKey("搜索"),
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
                            emptyMessage: viewModel.searchText.isEmpty ? String(localized: "Enter keywords to start searching") : String(localized: "No related packages found"),
                            actionButtonTitle: String(localized: "Install"),
                            actionButtonColor: DesignTokens.Color.semantic.success,
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
                ProgressView(String(localized: "Processing..."))
                    .padding()
                    .background(DesignTokens.Material.glass)
                    .cornerRadius(8)
            }
        }
        .alert(String(localized: "Error"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                GlassButton(title: LocalizedStringKey("Refresh"), style: .secondary) {
                    Task { await viewModel.refresh() }
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
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
        MystiqueGlassCard(cornerRadius: 12, padding: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(package.name)
                            .font(.headline)
                        
                        if package.isCask {
                            Text(String(localized: "Cask"))
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(DesignTokens.Color.gradients.energyGradient.opacity(0.2))
                                .foregroundColor(DesignTokens.Color.semantic.warning)
                                .cornerRadius(4)
                        }
                        
                        if showInstalledStatus {
                            if package.installedVersion != nil {
                                Text(String(localized: "Installed"))
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.Color.gradients.energyGradient)
                            }
                        }
                    }
                    
                    if let desc = package.desc {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        Text(String(localized: "Version: \(package.version)"))
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        
                        if let installedVer = package.installedVersion, installedVer != package.version {
                            Text(String(localized: "Installed: \(installedVer)"))
                                .font(.caption2)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                if showInstalledStatus && package.installedVersion != nil {
                    // 如果是搜索结果且已安装，显示已安装状态，不显示操作按钮
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Color.semantic.success)
                } else {
                    Button(action: action) {
                        Text(actionButtonTitle)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(actionButtonColor.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(actionButtonColor, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(actionButtonColor)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
