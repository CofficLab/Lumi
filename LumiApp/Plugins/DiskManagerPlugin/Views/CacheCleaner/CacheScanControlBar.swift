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
                    title: { Text(viewModel.isScanning ? String(localized: "停止扫描", table: "DiskManager") : String(localized: "扫描缓存", table: "DiskManager")) },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "doc.badge.gearshape") }
                )
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? Color(hex: "FF453A") : Color(hex: "FF9F0A"))

            Spacer()

            Text(String(localized: "扫描范围：用户主目录", table: "DiskManager"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    CacheScanControlBar(viewModel: CacheCleanerViewModel())
        .padding()
}
