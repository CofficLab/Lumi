import SwiftUI

/// 磁盘管理器主视图
struct DiskManagerView: View {
    @StateObject private var viewModel = DiskManagerViewModel()
    @State private var selectedViewMode = 0

    var body: some View {
        VStack(spacing: 0) {
            // 头部 - 磁盘使用情况
            DiskUsageInfoView()
                .padding()

            GlassDivider()

            // 视图模式选择器
            ViewModeSelector(selectedMode: $selectedViewMode)
                .padding(.horizontal)
                .padding(.vertical)

            // 内容区域 - 各模式自行负责显示状态和进度
            VStack {
                if selectedViewMode == 0 {
                    LargeFilesListView(viewModel: viewModel)
                } else if selectedViewMode == 1 {
                    DirectoryTreeView(viewModel: viewModel)
                } else if selectedViewMode == 2 {
                    CacheCleanerView()
                } else if selectedViewMode == 4 {
                    XcodeCleanerView()
                } else if selectedViewMode == 5 {
                    ProjectCleanerView()
                }
            }
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }
}

// MARK: - 子组件

/// 磁盘使用情况信息视图
struct DiskUsageInfoView: View {
    @StateObject private var viewModel = DiskManagerViewModel()

    var body: some View {
        MystiqueGlassCard(padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
            HStack(spacing: 40) {
                DiskUsageRingView()
                    .frame(width: 100, height: 100)

                if let usage = viewModel.diskUsage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macintosh HD")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("总计：\(formatBytes(usage.total))")
                            Text("已用：\(formatBytes(usage.used))")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            Text("可用：\(formatBytes(usage.available))")
                                .foregroundColor(DesignTokens.Color.semantic.success)
                        }
                        .font(.subheadline)
                    }
                } else {
                    ProgressView()
                }

                Spacer()
            }
        }
        .onAppear {
            viewModel.refreshDiskUsage()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        DiskManagerViewModel.byteFormatter.string(fromByteCount: bytes)
    }
}

/// 视图模式选择器
struct ViewModeSelector: View {
    @Binding var selectedMode: Int

    var body: some View {
        MystiqueGlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            HStack(spacing: 12) {
                Spacer()
                ViewModeButton(title: "大文件", icon: "doc.text", isSelected: selectedMode == 0) {
                withAnimation {
                        selectedMode = 0
                    }
                }

                ViewModeButton(title: "目录分析", icon: "folder", isSelected: selectedMode == 1) {
                    withAnimation {
                        selectedMode = 1
                    }
                }

                ViewModeButton(title: "系统清理", icon: "gear", isSelected: selectedMode == 2) {
                    withAnimation {
                        selectedMode = 2
                    }
                }

                ViewModeButton(title: "Xcode 清理", icon: "hammer", isSelected: selectedMode == 4) {
                    withAnimation {
                        selectedMode = 4
                    }
                }

                ViewModeButton(title: "项目清理", icon: "scissors", isSelected: selectedMode == 5) {
                    withAnimation {
                        selectedMode = 5
                    }
                }

                Spacer()
            }
        }
    }
}

/// 视图模式按钮
struct ViewModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textPrimary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textSecondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? DesignTokens.Color.semantic.primary.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
