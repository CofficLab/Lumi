import SwiftUI

/// 缓存清理扫描进度视图
struct CacheScanProgressView: View {
    @ObservedObject var viewModel: CacheCleanerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // 扫描图标和动画
            ZStack {
                // 外圈光晕
                Circle()
                    .stroke(
                        DesignTokens.Color.semantic.warning.opacity(0.2),
                        lineWidth: 8
                    )
                    .frame(width: 60, height: 60)

                // 旋转的扫描线
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        DesignTokens.Color.semantic.warning,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(viewModel.isScanning ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isScanning)

                // 中心图标
                Image(systemName: "doc.badge.gearshape")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Color.semantic.warning)
            }

            // 进度信息
            VStack(spacing: 6) {
                Text("正在扫描系统缓存")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gear")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text(viewModel.scanProgress.isEmpty ? "用户目录" : viewModel.scanProgress)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Label {
                        Text("\(viewModel.categories.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.primary)
                    } icon: {
                        Image(systemName: "folder.fill")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    Label {
                        Text("项")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.warning)
                    } icon: {
                        Image(systemName: "doc.badge.clock")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Color.semantic.warning.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignTokens.Color.semantic.warning.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical)
    }
}

#Preview {
    CacheScanProgressView(viewModel: CacheCleanerViewModel())
        .padding()
}
