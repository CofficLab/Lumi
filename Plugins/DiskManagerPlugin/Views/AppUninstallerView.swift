import SwiftUI

struct AppUninstallerView: View {
    @StateObject private var viewModel = AppUninstallerViewModel()
    
    var body: some View {
        HSplitView {
            // Left: App List
            VStack(spacing: 0) {
                if viewModel.isScanningApps {
                    ProgressView("Scanning Apps...")
                        .padding()
                } else if viewModel.apps.isEmpty {
                    ContentUnavailableView("No Apps Found", systemImage: "app.dashed")
                } else {
                    List(selection: Binding(
                        get: { viewModel.selectedApp },
                        set: { viewModel.selectApp($0!) }
                    )) {
                        ForEach(viewModel.apps) { app in
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: "app")
                                        .font(.title2)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(app.name)
                                        .font(.headline)
                                    Text(app.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                Text(formatBytes(app.size))
                                    .font(.monospacedDigit(.caption)())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .tag(app)
                        }
                    }
                }
            }
            .frame(minWidth: 250, maxWidth: .infinity)
            
            // Right: Details
            VStack(spacing: 0) {
                if let app = viewModel.selectedApp {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack(spacing: 16) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 64, height: 64)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.title)
                                Text(app.bundleId ?? "Unknown Bundle ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        
                        Divider()
                        
                        // Related Files List
                        if viewModel.isScanningFiles {
                            Spacer()
                            ProgressView("Scanning related files...")
                            Spacer()
                        } else {
                            List {
                                ForEach(viewModel.relatedFiles) { file in
                                    HStack {
                                        Toggle("", isOn: Binding(
                                            get: { viewModel.selectedFileIds.contains(file.id) },
                                            set: { _ in viewModel.toggleFileSelection(file.id) }
                                        ))
                                        
                                        VStack(alignment: .leading) {
                                            Text(file.type.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(file.path)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(formatBytes(file.size))
                                            .font(.monospacedDigit(.caption)())
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Footer Action
                        HStack {
                            Text("Selected: \(formatBytes(viewModel.totalSelectedSize))")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                viewModel.showDeleteConfirmation = true
                            } label: {
                                Text("Uninstall Selected")
                            }
                            .disabled(viewModel.selectedFileIds.isEmpty || viewModel.isDeleting)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Select an App", systemImage: "hand.tap")
                }
            }
            .frame(minWidth: 300, maxWidth: .infinity)
        }
        .onAppear {
            if viewModel.apps.isEmpty {
                viewModel.scanApps()
            }
        }
        .alert("Confirm Uninstall", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Uninstall", role: .destructive) {
                viewModel.deleteSelectedFiles()
            }
        } message: {
            Text("Are you sure you want to delete the selected files? This action cannot be undone.")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
