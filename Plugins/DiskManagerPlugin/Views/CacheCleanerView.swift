import SwiftUI

struct CacheCleanerView: View {
    @StateObject private var viewModel = CacheCleanerViewModel()
    @State private var showCleanConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("系统清理")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("扫描并清理系统缓存、日志和垃圾文件")
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
                    Button("重新扫描") {
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
                ContentUnavailableView("准备就绪", systemImage: "sparkles", description: Text("点击扫描开始分析系统垃圾"))
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
                    Text("选中: \(viewModel.formatBytes(viewModel.totalSelectedSize))")
                        .font(.headline)
                    Text("\(viewModel.selection.count) 个项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showCleanConfirmation = true
                }) {
                    Label(viewModel.isCleaning ? "正在清理..." : "立即清理", systemImage: "trash")
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
        .alert("确认清理", isPresented: $showCleanConfirmation) {
            Button("清理", role: .destructive) {
                viewModel.cleanSelected()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清理选中的 \(viewModel.formatBytes(viewModel.totalSelectedSize)) 文件吗？此操作不可撤销。")
        }
        .alert("清理完成", isPresented: $viewModel.showCleanupComplete) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("成功释放了 \(viewModel.formatBytes(viewModel.lastFreedSpace)) 空间。")
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
