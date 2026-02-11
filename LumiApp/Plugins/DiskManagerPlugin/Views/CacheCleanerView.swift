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
                    Text("Scan and clean system caches, logs, and junk files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if viewModel.isScanning {
                    VStack(alignment: .trailing) {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text(viewModel.scanProgress)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("Rescan") {
                        viewModel.scan()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            if viewModel.categories.isEmpty && !viewModel.isScanning {
                ContentUnavailableView("Ready", systemImage: "sparkles", description: Text("Click scan to start analyzing system junk"))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.categories) { category in
                        CacheCategorySection(category: category, viewModel: viewModel)
                    }
                }
                .listStyle(.sidebar) // Or .insetGrouped
            }
            
            Divider()
            
            // Footer Action
            HStack {
                VStack(alignment: .leading) {
                    Text("Selected: \(viewModel.formatBytes(viewModel.totalSelectedSize))")
                        .font(.headline)
                    Text("\(viewModel.selection.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showCleanConfirmation = true
                }) {
                    Label(viewModel.isCleaning ? "Cleaning..." : "Clean Now", systemImage: "trash")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.selection.isEmpty || viewModel.isCleaning || viewModel.isScanning)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            if viewModel.categories.isEmpty {
                viewModel.scan()
            }
        }
        .alert("Confirm Cleanup", isPresented: $showCleanConfirmation) {
            Button("Clean", role: .destructive) {
                viewModel.cleanSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clean the selected \(viewModel.formatBytes(viewModel.totalSelectedSize)) files? This action cannot be undone.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showCleanupComplete) {
            Button("OK", role: .cancel) {}
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
                
                Spacer()
                
                // Safety Badge
                Text(category.safetyLevel.label)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(category.safetyLevel.color).opacity(0.2))
                    .foregroundStyle(Color(category.safetyLevel.color))
                    .cornerRadius(4)
                
                Text(viewModel.formatBytes(category.totalSize))
                    .font(.monospacedDigit(.caption)())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

struct CachePathRow: View {
    let path: CachePath
    let isSelected: Bool
    let toggleAction: () -> Void
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(get: { isSelected }, set: { _ in toggleAction() }))
                .labelsHidden()
            
            if let icon = path.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "doc")
            }
            
            VStack(alignment: .leading) {
                Text(path.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(path.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Text(formatBytes(path.size))
                .font(.monospacedDigit(.caption)())
                .foregroundStyle(.secondary)
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
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
