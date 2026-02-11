import SwiftUI

struct DiskManagerView: View {
    @StateObject private var viewModel = DiskManagerViewModel()
    @State private var selectedViewMode = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Dashboard
            if let usage = viewModel.diskUsage {
                GlassCard(padding: 20) {
                    HStack(spacing: 40) {
                        DiskUsageRingView(percentage: usage.usedPercentage)
                            .frame(width: 100, height: 100)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Macintosh HD")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total: \(viewModel.formatBytes(usage.total))")
                                Text("Used: \(viewModel.formatBytes(usage.used))")
                                    .foregroundStyle(.secondary)
                                Text("Available: \(viewModel.formatBytes(usage.available))")
                                    .foregroundStyle(.green)
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
                                Label(viewModel.isScanning ? "Stop Scan" : "Scan Large Files", systemImage: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle")
                                    .font(.headline)
                                    .padding()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(viewModel.isScanning ? .red : .blue)
                            
                            Text("Scan Directory: User Home")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
                // .onAppear moved to bottom
            }
            
            Divider()
            
            // View Mode Picker
            GlassCard(padding: 16) {
                Picker("View Mode", selection: $selectedViewMode) {
                    Text("Large Files").tag(0)
                    Text("Directory Analysis").tag(1)
                    Text("System Cleanup").tag(2)
                    Text("Xcode Cleanup").tag(4)
                    Text("Project Cleanup").tag(5)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
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
                            Text("Scanning: \(progress.currentPath)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            HStack {
                                Text("\(progress.scannedFiles) files")
                                Text("•")
                                Text(viewModel.formatBytes(progress.scannedBytes))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Preparing scan...")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
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
            ContentUnavailableView("No Large Files", systemImage: "doc.text.magnifyingglass", description: Text("Click scan button to start finding large files"))
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
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
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
                Text("Used")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(viewModel.formatBytes(item.size))
                    .font(.monospacedDigit(.body)())
                    .foregroundStyle(.secondary)
                
                Text(item.fileType.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.revealInFinder(item)
                }) {
                    Image(systemName: "folder")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
                
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
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
