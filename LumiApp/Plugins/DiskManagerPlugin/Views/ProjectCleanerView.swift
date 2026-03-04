import SwiftUI

struct ProjectCleanerView: View {
    @StateObject private var viewModel = ProjectCleanerViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            contentView
            
            footerView
        }
        .onAppear {
            if viewModel.projects.isEmpty {
                viewModel.scanProjects()
            }
        }
        .alert(Text("Confirm Cleanup"), isPresented: $viewModel.showCleanConfirmation) {
            Button(role: .cancel) { } label: {
                Text("Cancel")
            }
            Button(role: .destructive) {
                viewModel.cleanSelected()
            } label: {
                Text("Clean")
            }
        } message: {
            Text("Are you sure you want to delete the selected build artifacts (node_modules, target, etc)?\nThis will free up space but require rebuilding projects.")
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Project Cleaner")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            Spacer()
            GlassButton(title: LocalizedStringKey("Rescan"), style: .secondary) {
                viewModel.scanProjects()
            }
            .disabled(viewModel.isScanning)
        }
        .padding()
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isScanning {
            scanningView
        } else if viewModel.projects.isEmpty {
            emptyView
        } else {
            projectListView
        }
    }
    
    private var scanningView: some View {
        VStack {
            Spacer()
            ProgressView {
                Text("Scanning projects in common directories...")
            }
            Spacer()
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            label: { Text("No Cleanable Projects Found") },
            description: { Text("Scanned: Code, Projects, Developer, etc.") },
            actions: { EmptyView() }
        )
    }
    
    private var projectListView: some View {
        List {
            ForEach(viewModel.projects) { project in
                Section {
                    ForEach(project.cleanableItems) { item in
                        ProjectItemRow(item: item, viewModel: viewModel)
                    }
                } header: {
                    ProjectSectionHeader(project: project)
                }
            }
        }
    }
    
    private var footerView: some View {
        VStack {
            Divider()
            HStack {
                VStack(alignment: .leading) {
                    Text("Selected for cleanup")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(viewModel.formatBytes(viewModel.totalSelectedSize))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
                
                Spacer()
                
                GlassButton(title: viewModel.isCleaning ? LocalizedStringKey("Cleaning...") : LocalizedStringKey("Clean Now"), style: .primary) {
                    viewModel.cleanSelected()
                }
                .disabled(viewModel.selectedItemIds.isEmpty || viewModel.isCleaning || viewModel.isScanning)
            }
            .padding()
        }
        .background(DesignTokens.Material.glass)
    }
}

// MARK: - Helper Views

struct ProjectItemRow: View {
    let item: CleanableItem
    @ObservedObject var viewModel: ProjectCleanerViewModel
    
    var body: some View {
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
            
            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.body)())
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
    }
}

struct ProjectSectionHeader: View {
    let project: ProjectInfo
    
    var body: some View {
        HStack {
            Image(systemName: project.type.icon)
            Text(project.name)
                .font(.headline)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            Spacer()
            Text(project.type.displayName)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
