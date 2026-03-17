import SwiftUI

/// 缓存清理扫描控制栏
struct CacheScanControlBar: View {
    @ObservedObject var viewModel: CacheCleanerViewModel

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    viewModel.scan()
                }
            }, label: {
                Label(
                    title: { Text(viewModel.isScanning ? "停止扫描" : "扫描缓存") },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "doc.badge.gearshape") }
                )
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? DesignTokens.Color.semantic.error : DesignTokens.Color.semantic.warning)

            Spacer()

            Text("扫描范围：用户主目录")
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    CacheScanControlBar(viewModel: CacheCleanerViewModel())
        .padding()
}
