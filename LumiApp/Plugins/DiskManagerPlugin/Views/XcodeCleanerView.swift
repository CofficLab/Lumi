import SwiftUI

struct XcodeCleanerView: View {
    @StateObject private var viewModel = XcodeCleanerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Free up disk space by cleaning obsolete build and support files")
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning...")
                        .foregroundStyle(.secondary)
                } else {
                    Button(action: {
                        Task { await viewModel.scanAll() }
                    }) {
                        Label("Rescan", systemImage: "arrow.clockwise")
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
                    Text("Selected: \(viewModel.formatBytes(viewModel.selectedSize))")
                        .font(.headline)
                    Text("Total: \(viewModel.formatBytes(viewModel.totalSize))")
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
                    Text("Clean Now")
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
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle")
            .font(.system(size: 64))
            .foregroundStyle(.green)
            Text("No items to clean")
            .font(.title2)
            Text("Your Xcode environment is clean!")
            .foregroundStyle(.secondary)
            Button("Rescan") {
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
        .inRootView()
        .withDebugBar()
}
