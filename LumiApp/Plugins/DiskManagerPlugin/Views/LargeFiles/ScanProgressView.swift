import SwiftUI

/// 扫描进度视图
struct ScanProgressView: View {
    @ObservedObject var viewModel: DiskManagerViewModel

    var body: some View {
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
        .frame(maxHeight: .infinity)
        .background(DesignTokens.Material.glass.opacity(0.2))
    }
}

// MARK: - 预览

#Preview {
    ScanProgressView(viewModel: DiskManagerViewModel())
}
