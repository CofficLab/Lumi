import SwiftUI

struct XcodeCleanerView: View {
    @StateObject private var viewModel = XcodeCleanerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("释放磁盘空间，清理过时的构建文件和支持文件")
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("扫描中...")
                        .foregroundStyle(.secondary)
                } else {
                    Button(action: {
                        Task { await viewModel.scanAll() }
                    }) {
                        Label("重新扫描", systemImage: "arrow.clockwise")
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            if viewModel.itemsByCategory.isEmpty && !viewModel.isScanning {
                emptyStateView
            } else {
                List {
                    ForEach(XcodeCleanCategory.allCases) { category in
                        if let items = viewModel.itemsByCategory[category], !items.isEmpty {
                            CategorySection(category: category, items: items, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer
            HStack {
                VStack(alignment: .leading) {
                    Text("选中: \(viewModel.formatBytes(viewModel.selectedSize))")
                        .font(.headline)
                    Text("总计: \(viewModel.formatBytes(viewModel.totalSize))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button(action: {
                    Task { await viewModel.cleanSelected() }
                }) {
                    Text("立即清理")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedSize == 0 || viewModel.isCleaning)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            Task { await viewModel.scanAll() }
        }
        .navigationTitle("Xcode 清理")
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("未发现可清理项目")
                .font(.title2)
            Text("您的 Xcode 环境非常干净！")
                .foregroundStyle(.secondary)
            Button("重新扫描") {
                Task { await viewModel.scanAll() }
            }
            Spacer()
        }
    }
}

struct CategorySection: View {
    let category: XcodeCleanCategory
    let items: [XcodeCleanItem]
    @ObservedObject var viewModel: XcodeCleanerViewModel
    @State private var isExpanded = true

    var selectedCount: Int {
        items.filter { $0.isSelected }.count
    }

    var categorySize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        Section(header: headerView) {
            if isExpanded {
                ForEach(items) { item in
                    ItemRow(item: item, viewModel: viewModel)
                }
            }
        }
    }

    var headerView: some View {
        HStack {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: category.iconName)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text(category.rawValue)
                    .font(.headline)
                Text(category.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(viewModel.formatBytes(categorySize))
                .font(.monospacedDigit(.body)())
                .foregroundStyle(.secondary)

            // 全选/反选 Checkbox
            Toggle("", isOn: Binding(
                get: { selectedCount == items.count && items.count > 0 },
                set: { isSelected in
                    if isSelected {
                        viewModel.selectAll(in: category)
                    } else {
                        viewModel.deselectAll(in: category)
                    }
                }
            ))
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 8)
    }
}

struct ItemRow: View {
    let item: XcodeCleanItem
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .padding(.leading, 24) // Indent

            VStack(alignment: .leading) {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.path.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.caption)())
                .foregroundStyle(.secondary)

            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in viewModel.toggleSelection(for: item) }
            ))
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 4)
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(XcodeCleanerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
