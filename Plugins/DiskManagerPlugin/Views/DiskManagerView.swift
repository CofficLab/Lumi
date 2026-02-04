import SwiftUI

struct DiskManagerView: View {
    @StateObject private var viewModel = DiskManagerViewModel()
    @State private var selectedViewMode = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Dashboard
            if let usage = viewModel.diskUsage {
                HStack(spacing: 40) {
                    DiskUsageRingView(percentage: usage.usedPercentage)
                        .frame(width: 100, height: 100)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macintosh HD")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("总空间: \(viewModel.formatBytes(usage.total))")
                            Text("已用: \(viewModel.formatBytes(usage.used))")
                                .foregroundStyle(.secondary)
                            Text("可用: \(viewModel.formatBytes(usage.available))")
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
                            Label(viewModel.isScanning ? "停止扫描" : "扫描大文件", systemImage: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle")
                                .font(.headline)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isScanning ? .red : .blue)
                        
                        Text("扫描目录: 用户主目录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                ProgressView()
                // .onAppear 移到底部
            }
            
            Divider()
            
            // View Mode Picker
            Picker("视图模式", selection: $selectedViewMode) {
                Text("大文件").tag(0)
                Text("目录分析").tag(1)
                Text("系统清理").tag(2)
                Text("系统监控").tag(3)
                Text("应用卸载").tag(4)
                Text("项目清理").tag(5)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            VStack {
                if selectedViewMode == 0 {
                    LargeFilesListView(viewModel: viewModel)
                } else if selectedViewMode == 1 {
                    DirectoryTreeView(entries: viewModel.rootEntries)
                } else if selectedViewMode == 2 {
                    CacheCleanerView()
                } else if selectedViewMode == 3 {
                    SystemMonitorView()
                } else if selectedViewMode == 4 {
                    AppUninstallerView()
                } else {
                    ProjectCleanerView()
                }
            }
            
            Spacer()
            
            // Scanning Progress
            if viewModel.isScanning && selectedViewMode != 2 && selectedViewMode != 3 && selectedViewMode != 4 && selectedViewMode != 5 {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    if let progress = viewModel.scanProgress {
                        VStack(spacing: 4) {
                            Text("正在扫描: \(progress.currentPath)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            HStack {
                                Text("\(progress.scannedFiles) 个文件")
                                Text("•")
                                Text(viewModel.formatBytes(progress.scannedBytes))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("正在准备扫描...")
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
            ContentUnavailableView("无大文件", systemImage: "doc.text.magnifyingglass", description: Text("点击扫描按钮开始查找大文件"))
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
                Text("已用")
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
                .help("在 Finder 中显示")
                
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("删除文件")
                .confirmationDialog("确定要删除此文件吗？", isPresented: $showDeleteConfirm) {
                    Button("删除", role: .destructive) {
                        viewModel.deleteFile(item)
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("文件 \"\(item.name)\" 将被永久删除。")
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
