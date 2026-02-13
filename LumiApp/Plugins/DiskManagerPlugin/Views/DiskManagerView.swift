import SwiftUI

struct DiskManagerView: View {
    @StateObject private var viewModel = DiskManagerViewModel()
    @State private var selectedViewMode = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Dashboard
            if let usage = viewModel.diskUsage {
                MystiqueGlassCard(padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
                    HStack(spacing: 40) {
                        DiskUsageRingView(percentage: usage.usedPercentage)
                            .frame(width: 100, height: 100)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Macintosh HD", tableName: "DiskManager")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total: \(viewModel.formatBytes(usage.total))", tableName: "DiskManager")
                                Text("Used: \(viewModel.formatBytes(usage.used))", tableName: "DiskManager")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                Text("Available: \(viewModel.formatBytes(usage.available))", tableName: "DiskManager")
                                .foregroundColor(DesignTokens.Color.semantic.success)
                            }
                            .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Button(action: {
                                if viewModel.isScanning {
                                    viewModel.stopScan()
                                } else {
                                    viewModel.startScan()
                                }
                            }) {
                                Label {
                                    Text(viewModel.isScanning ? "Stop Scan" : "Scan Large Files", tableName: "DiskManager")
                                } icon: {
                                    Image(systemName: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle")
                                }
                                .font(.headline)
                                .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(viewModel.isScanning ? DesignTokens.Color.semantic.error : DesignTokens.Color.semantic.info)
                            
                            Text("Scan Directory: User Home", tableName: "DiskManager")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
                // .onAppear moved to bottom
            }
            
            GlassDivider()
            
            // View Mode Picker
            MystiqueGlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                Picker(selection: $selectedViewMode) {
                    Text("Large Files", tableName: "DiskManager").tag(0)
                    Text("Directory Analysis", tableName: "DiskManager").tag(1)
                    Text("System Cleanup", tableName: "DiskManager").tag(2)
                    Text("Xcode Cleanup", tableName: "DiskManager").tag(4)
                    Text("Project Cleanup", tableName: "DiskManager").tag(5)
                } label: {
                    Text("View Mode", tableName: "DiskManager")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.vertical)
            
            // Content
            VStack {
                if selectedViewMode == 0 {
                    LargeFilesListView(viewModel: viewModel)
                } else if selectedViewMode == 1 {
                    DirectoryTreeView(entries: viewModel.rootEntries)
                } else if selectedViewMode == 2 {
                    CacheCleanerView()
                } else if selectedViewMode == 4 {
                    XcodeCleanerView()
                } else if selectedViewMode == 5 {
                    ProjectCleanerView()
                }
            }
            
            Spacer()
            
            // Scanning Progress
            if viewModel.isScanning && selectedViewMode != 2 && selectedViewMode != 5 {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    if let progress = viewModel.scanProgress {
                        VStack(spacing: 4) {
                            Text("Scanning: \(progress.currentPath)", tableName: "DiskManager")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            HStack {
                                Text("\(progress.scannedFiles) files", tableName: "DiskManager")
                                Text("•")
                                Text(viewModel.formatBytes(progress.scannedBytes))
                            }
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    } else {
                        Text("Preparing scan...", tableName: "DiskManager")
                    }
                }
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignTokens.Material.glass.opacity(0.2))
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(DesignTokens.Color.semantic.error)
                    .padding()
            }
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }
}

struct LargeFilesListView: View {
    @ObservedObject var viewModel: DiskManagerViewModel
    
    var body: some View {
        if viewModel.largeFiles.isEmpty && !viewModel.isScanning {
            ContentUnavailableView {
                Text("No Large Files", tableName: "DiskManager")
            } description: {
                Text("Click scan button to start finding large files", tableName: "DiskManager")
            }
        } else {
            List {
                ForEach(viewModel.largeFiles) { file in
                    LargeFileRow(item: file, viewModel: viewModel)
                }
            }
            .listStyle(.inset)
        }
    }
}

struct DiskUsageRingView: View {
    let percentage: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.2), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [DesignTokens.Color.semantic.info, DesignTokens.Color.semantic.primary]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * percentage)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            VStack {
                Text("\(Int(percentage * 100))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text("Used")
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
    }
}

struct LargeFileRow: View {
    let item: LargeFileEntry
    @ObservedObject var viewModel: DiskManagerViewModel
    @State private var showDeleteConfirm = false
    
    var body: some View {
        HStack {
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(viewModel.formatBytes(item.size))
                    .font(.monospacedDigit(.body)())
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                
                Text(item.fileType.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    .padding(.horizontal, 4)
                    .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.revealInFinder(item)
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(DesignTokens.Color.semantic.info)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(DesignTokens.Color.semantic.error)
                }
                .buttonStyle(.plain)
                .help("Delete File")
                .confirmationDialog("Are you sure you want to delete this file?", isPresented: $showDeleteConfirm) {
                    Button("Delete", role: .destructive) {
                        viewModel.deleteFile(item)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("File \"\(item.name)\" will be permanently deleted.")
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DiskManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
