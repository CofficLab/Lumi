import SwiftUI

struct XcodeCleanerView: View {
    @StateObject private var viewModel = XcodeCleanerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Free up disk space by cleaning obsolete build and support files")
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Spacer()

                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning...")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                } else {
                    GlassButton(title: "Rescan", style: .secondary) {
                        Task { await viewModel.scanAll() }
                    }
                }
            }
            .padding()
            .background(DesignTokens.Material.glass)

            GlassDivider()

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

            GlassDivider()

            // Footer
            HStack {
                VStack(alignment: .leading) {
                    Text("Selected: \(viewModel.formatBytes(viewModel.selectedSize))")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Text("Total: \(viewModel.formatBytes(viewModel.totalSize))")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                Spacer()

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(DesignTokens.Color.semantic.error)
                        .font(.caption)
                }

                GlassButton(title: "Clean Now", style: .primary) {
                    Task { await viewModel.cleanSelected() }
                }
                .disabled(viewModel.selectedSize == 0 || viewModel.isCleaning)
            }
            .padding()
            .background(DesignTokens.Material.glass)
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
                .foregroundColor(DesignTokens.Color.semantic.success)
            Text("No items to clean")
                .font(.title2)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            Text("Your Xcode environment is clean!")
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            GlassButton(title: "Rescan", style: .secondary) {
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
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)

            Image(systemName: category.iconName)
                .foregroundColor(DesignTokens.Color.semantic.info)

            VStack(alignment: .leading) {
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(category.description)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()

            Text(viewModel.formatBytes(categorySize))
                .font(.monospacedDigit(.body)())
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .padding(.leading, 24) // Indent

            VStack(alignment: .leading) {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(item.path.path)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.caption)())
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

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
