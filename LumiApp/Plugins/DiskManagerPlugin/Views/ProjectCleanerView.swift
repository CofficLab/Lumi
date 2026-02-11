import SwiftUI

struct ProjectCleanerView: View {
    @StateObject private var viewModel = ProjectCleanerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Project Cleaner")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Spacer()
                GlassButton(title: "Rescan", style: .secondary) {
                    viewModel.scanProjects()
                }
                .disabled(viewModel.isScanning)
            }
            .padding()
            
            // Content
            if viewModel.isScanning {
                Spacer()
                ProgressView("Scanning projects in common directories...")
                Spacer()
            } else if viewModel.projects.isEmpty {
                ContentUnavailableView("No Cleanable Projects Found", 
                                     systemImage: "folder.badge.questionmark",
                                     description: Text("Scanned: Code, Projects, Developer, etc."))
            } else {
                List {
                    ForEach(viewModel.projects) { project in
                        Section {
                            ForEach(project.cleanableItems) { item in
                                HStack {
                                    Toggle("", isOn: Binding(
                                        get: { viewModel.selectedItemIds.contains(item.id) },
                                        set: { _ in viewModel.toggleSelection(item.id) }
                                    ))
                                    .labelsHidden()
                                    
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(DesignTokens.Color.semantic.warning)
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                            .font(.body)
                                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                        Text(item.path)
                                            .font(.caption2)
                                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(formatBytes(item.size))
                                        .font(.monospacedDigit(.body)())
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                }
                            }
                        } header: {
                            HStack {
                                Image(systemName: project.type.icon)
                                Text(project.name)
                                    .font(.headline)
                                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                Spacer()
                                Text(project.type.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            
            // Footer
            VStack {
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Selected for cleanup")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text(formatBytes(viewModel.totalSelectedSize))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    }
                    
                    Spacer()
                    
                    GlassButton(title: "Clean Selected", style: .danger) {
                        viewModel.showCleanConfirmation = true
                    }
                    .disabled(viewModel.selectedItemIds.isEmpty || viewModel.isCleaning)
                }
                .padding()
            }
            .background(DesignTokens.Material.glass)
        }
        .onAppear {
            if viewModel.projects.isEmpty {
                viewModel.scanProjects()
            }
        }
        .alert("Confirm Cleanup", isPresented: $viewModel.showCleanConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                viewModel.cleanSelected()
            }
        } message: {
            Text("Are you sure you want to delete the selected build artifacts (node_modules, target, etc)?\nThis will free up space but require rebuilding projects.")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
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
