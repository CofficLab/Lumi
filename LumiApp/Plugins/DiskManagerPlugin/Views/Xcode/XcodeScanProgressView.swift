import SwiftUI

/// Xcode 清理扫描进度视图
struct XcodeScanProgressView: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // 扫描图标和动画
            ZStack {
                // 外圈光晕
                Circle()
                    .stroke(
                        DesignTokens.Color.semantic.info.opacity(0.2),
                        lineWidth: 8
                    )
                    .frame(width: 60, height: 60)

                // 旋转的扫描线
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        DesignTokens.Color.semantic.info,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(viewModel.isScanning ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: viewModel.isScanning)

                // 中心图标
                Image(systemName: "hammer")
                    .font(.system(size: 24))
                    .foregroundColor(DesignTokens.Color.semantic.info)
            }

            // 进度信息
            VStack(spacing: 6) {
                Text("正在扫描 Xcode 缓存")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gear")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Text("开发者缓存目录")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 16) {
                    Label {
                        Text("\(viewModel.itemsByCategory.values.flatMap { $0 }.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.primary)
                    } icon: {
                        Image(systemName: "doc.fill")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }

                    Label {
                        Text(viewModel.formatBytes(viewModel.totalSize))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Color.semantic.info)
                    } icon: {
                        Image(systemName: "internaldrive.fill")
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignTokens.Color.semantic.info.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignTokens.Color.semantic.info.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical)
    }
}

#Preview {
    XcodeScanProgressView(viewModel: XcodeCleanerViewModel())
        .padding()
}
