import SwiftUI

/// 缓存清理扫描控制栏
struct CacheScanControlBar: View {
    @ObservedObject var viewModel: CacheCleanerViewModel

    var body: some View {
        HStack {
            Button(action: {
                viewModel.scan()
            }, label: {
                Label(title: { Text("重新扫描") }, icon: {
                    Image(systemName: "arrow.clockwise")
                })
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Color.semantic.info)

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
