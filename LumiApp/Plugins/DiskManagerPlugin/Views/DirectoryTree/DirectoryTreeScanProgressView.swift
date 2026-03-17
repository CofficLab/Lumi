import SwiftUI

/// 目录树扫描进度视图
struct DirectoryTreeScanProgressView: View {
    @ObservedObject var viewModel: DiskManagerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // 扫描图标和动画
            ZStack {
                // 外圈光晕
                Circle()
                    .stroke(
                        DesignTokens.Color.semantic.primary.opacity(0.2),
                        lineWidth: 8
                    )
                    .frame(width: 60, height: 60)

                // 旋转的扫描线
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        DesignTokens.Color.semantic.primary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)

                // 中心图标
                Image(systemName: "folder.badge.gear")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
            }

            // 进度信息
            VStack(spacing: 6) {
                if let progress = viewModel.scanProgress {
                    Text("正在分析目录结构")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text(URL(fileURLWithPath: progress.currentPath).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    HStack(spacing: 16) {
                        Label {
                            Text("\(progress.scannedFiles)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(DesignTokens.Color.semantic.primary)
                        } icon: {
                            Image(systemName: "folder.fill")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }

                        Label {
                            Text(viewModel.formatBytes(progress.scannedBytes))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(DesignTokens.Color.semantic.info)
                        } icon: {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                } else {
                    Text("准备分析目录...")
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Color.semantic.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignTokens.Color.semantic.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical)
    }

    private var isAnimating: Bool {
        viewModel.isScanning
    }
}

#Preview {
    DirectoryTreeScanProgressView(viewModel: DiskManagerViewModel())
        .padding()
}
