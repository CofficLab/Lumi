import MagicKit
import OSLog
import SwiftUI

struct BrewManagerView: View, SuperLog {
    static let emoji = "🍺"
    static let verbose = true

    @StateObject private var viewModel = BrewManagerViewModel()
    @State private var selectedTab: BrewTab = .installed

    enum BrewTab: String, CaseIterable, Identifiable {
        case installed = "已安装"
        case updates = "更新"
        case search = "搜索"

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
            Picker("视图", selection: $selectedTab) {
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
                        emptyMessage: "没有安装任何包",
                        actionButtonTitle: "卸载",
                        actionButtonColor: .red
                    ) { package in
                        Task { await viewModel.uninstall(package: package) }
                    }

                case .updates:
                    VStack {
                        if !viewModel.outdatedPackages.isEmpty {
                            HStack {
                                Spacer()
                                Button("全部更新") {
                                    Task { await viewModel.upgradeAll() }
                                }
                                .padding()
                            }
                        }

                        BrewListView(
                            packages: viewModel.outdatedPackages,
                            emptyMessage: "所有包都是最新的",
                            actionButtonTitle: "更新",
                            actionButtonColor: .blue
                        ) { package in
                            Task { await viewModel.upgrade(package: package) }
                        }
                    }

                case .search:
                    VStack {
                        HStack {
                            TextField("搜索 Homebrew 包...", text: $viewModel.searchText)
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
                            emptyMessage: viewModel.searchText.isEmpty ? "输入关键词开始搜索" : "未找到相关包",
                            actionButtonTitle: "安装",
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
                ProgressView("处理中...")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
            }
        }
        .alert("错误", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    if Self.verbose {
                        os_log("\(self.t) 🚀 开始刷新")
                    }
                    Task { await viewModel.refresh() }
                }) {
                    Label("刷新", systemImage: "arrow.clockwise")
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
                            Text("已安装")
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
                    Text("版本: \(package.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let installedVer = package.installedVersion, installedVer != package.version {
                        Text("已装: \(installedVer)")
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
