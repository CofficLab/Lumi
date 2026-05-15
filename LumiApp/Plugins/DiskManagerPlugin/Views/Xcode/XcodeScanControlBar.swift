import SwiftUI

/// Xcode 清理扫描控制栏
struct XcodeScanControlBar: View {
    @ObservedObject var viewModel: XcodeCleanerViewModel

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    Task { await viewModel.scanAll() }
                }
            }, label: {
                Label(
                    title: { Text(viewModel.isScanning ? String(localized: "停止扫描", table: "DiskManager") : String(localized: "扫描 Xcode", table: "DiskManager")) },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "hammer") }
                )
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? Color(hex: "FF453A") : Color(hex: "0A84FF"))

            Spacer()

            Text(String(localized: "扫描范围：Xcode 相关缓存目录", table: "DiskManager"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    XcodeScanControlBar(viewModel: XcodeCleanerViewModel())
        .padding()
}
