import SwiftUI

struct CacheCleanerView: View {
    @StateObject private var viewModel = CacheCleanerViewModel()
    @State private var showCleanConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("System Cleanup")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Text("Scan and clean system caches, logs, and junk files")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                
                Spacer()
                
                if viewModel.isScanning {
                    VStack(alignment: .trailing) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text(viewModel.scanProgress)
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                } else {
                    GlassButton(title: LocalizedStringKey("Rescan"), style: .secondary) {
                        viewModel.scan()
                    }
                }
            }
            .padding()
            .background(DesignTokens.Material.glass)
            
            GlassDivider()
            
            // Content
            if viewModel.categories.isEmpty && !viewModel.isScanning {
                ContentUnavailableView(
                    label: { Text("Ready") },
                    description: { Text("Click scan to start analyzing system junk") },
                    actions: { EmptyView() }
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.categories) { category in
                        CacheCategorySection(category: category, viewModel: viewModel)
                    }
                }
                .listStyle(.sidebar) // Or .insetGrouped
            }
            
            GlassDivider()
            
            // Footer Action
            HStack {
                VStack(alignment: .leading) {
                    Text("Selected: \(viewModel.formatBytes(viewModel.totalSelectedSize))")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Text("\(viewModel.selection.count) items")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                
                Spacer()
                
                GlassButton(title: viewModel.isCleaning ? LocalizedStringKey("Cleaning...") : LocalizedStringKey("Clean Now"), style: .primary) {
                    showCleanConfirmation = true
                }
                .disabled(viewModel.selection.isEmpty || viewModel.isCleaning || viewModel.isScanning)
            }
            .padding()
            .background(DesignTokens.Material.glass)
        }
        .onAppear {
            if viewModel.categories.isEmpty {
                viewModel.scan()
            }
        }
        .alert(Text("Confirm Cleanup"), isPresented: $showCleanConfirmation) {
            Button(role: .destructive) {
                viewModel.cleanSelected()
            } label: {
                Text("Clean")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel")
            }
        } message: {
            Text("Are you sure you want to clean the selected \(viewModel.formatBytes(viewModel.totalSelectedSize)) files? This action cannot be undone.")
        }
        .alert(Text("Cleanup Complete"), isPresented: $viewModel.showCleanupComplete) {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        } message: {
            Text("Successfully freed \(viewModel.formatBytes(viewModel.lastFreedSpace)) space.")
        }
    }
}

struct CacheCategorySection: View {
    let category: CacheCategory
    @ObservedObject var viewModel: CacheCleanerViewModel
    @State private var isExpanded = true
    
    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach(category.paths) { path in
                CachePathRow(path: path, isSelected: viewModel.selection.contains(path.id)) {
                    viewModel.toggleSelection(for: path)
                }
            }
        } header: {
            HStack {
                Image(systemName: category.icon)
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                
                Spacer()
                
                // Safety Badge
                Text(category.safetyLevel.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Color.semantic.warning.opacity(0.2))
                    .foregroundColor(DesignTokens.Color.semantic.warning)
                    .cornerRadius(4)
                
                Text(viewModel.formatBytes(category.totalSize))
                    .font(.monospacedDigit(.caption)())
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.vertical, 4)
        }
    }
}

struct CachePathRow: View {
    let path: CachePath
    let isSelected: Bool
    let toggleAction: () -> Void

    // 在 UI 层计算图标（避免在 Sendable 模型中存储 NSImage）
    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path.path)
    }

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in toggleAction() }))
                .labelsHidden()

            Image(nsImage: icon)
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading) {
                Text(path.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(path.path)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(formatBytes(path.size))
                .font(.monospacedDigit(.caption)())
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
