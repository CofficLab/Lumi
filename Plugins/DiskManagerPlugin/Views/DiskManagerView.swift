import SwiftUI

struct DiskManagerView: View {
    @StateObject private var viewModel = DiskManagerViewModel()
    
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
                    .onAppear { viewModel.refreshDiskUsage() }
            }
            
            Divider()
            
            Spacer()
            
            // Scanning Progress
            if viewModel.isScanning {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在扫描: \(viewModel.currentScanningPath)")
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.05))
            }
            
            // Large Files List
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
            
            Spacer()
        }
        .onAppear {
            viewModel.refreshDiskUsage()
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
    let item: FileItem
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
            
            Text(viewModel.formatBytes(item.size))
                .font(.monospacedDigit(.body)())
                .foregroundStyle(.secondary)
            
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
