import SwiftUI

struct DiskManagerView: View {
    @StateObject private var viewModel = DiskManagerViewModel()
    @State private var selectedViewMode = 0

    var body: some View {
        VStack(spacing: 0) {
            // 头部 / 仪表盘
            if let usage = viewModel.diskUsage {
                MystiqueGlassCard(padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
                    HStack(spacing: 40) {
                        DiskUsageRingView(percentage: usage.usedPercentage)
                            .frame(width: 100, height: 100)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Macintosh HD")
                                .font(.title2)
                                .fontWeight(.bold)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("总计：\(viewModel.formatBytes(usage.total))")
                                Text("已用：\(viewModel.formatBytes(usage.used))")
                                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                Text("可用：\(viewModel.formatBytes(usage.available))")
                                    .foregroundColor(DesignTokens.Color.semantic.success)
                            }
                            .font(.subheadline)
                        }

                        Spacer()

                        VStack {
                            Text("扫描目录：用户主目录")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
                // .onAppear 已移至底部
            }

            GlassDivider()

            // 视图模式选择器
            MystiqueGlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                Picker(selection: $selectedViewMode) {
                    Text("大文件").tag(0)
                    Text("目录分析").tag(1)
                    Text("系统清理").tag(2)
                    Text("Xcode 清理").tag(4)
                    Text("项目清理").tag(5)
                } label: {
                    Text("视图模式")
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            .padding(.vertical)

            // 内容
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

            // 扫描进度
            if viewModel.isScanning && selectedViewMode != 2 && selectedViewMode != 5 {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)

                    if let progress = viewModel.scanProgress {
                        VStack(spacing: 4) {
                            Text("正在扫描：\(progress.currentPath)")
                                .lineLimit(1)
                                .truncationMode(.middle)

                            HStack {
                                Text("\(progress.scannedFiles) 个文件")
                                Text("•")
                                Text(viewModel.formatBytes(progress.scannedBytes))
                            }
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    } else {
                        Text("正在准备扫描...")
                    }
                }
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(DesignTokens.Material.glass.opacity(0.2))
            }

            // 错误消息
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

// MARK: - 预览

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DiskManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
