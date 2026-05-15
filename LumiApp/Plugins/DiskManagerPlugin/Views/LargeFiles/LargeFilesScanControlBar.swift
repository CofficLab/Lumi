import SwiftUI

/// 大文件扫描控制栏视图 - 用于启动/停止扫描操作
struct LargeFilesScanControlBar: View {
    @ObservedObject var viewModel: LargeFilesViewModel

    var body: some View {
        HStack {
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScan()
                } else {
                    viewModel.startScan()
                }
            }, label: {
                Label(
                    title: { Text(viewModel.isScanning ? String(localized: "停止扫描", table: "DiskManager") : String(localized: "扫描大文件", table: "DiskManager")) },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "magnifyingglass.circle") }
                )
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? Color(hex: "FF453A") : Color(hex: "0A84FF"))

            Spacer()

            Text(String(localized: "扫描目录：用户主目录", table: "DiskManager"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    LargeFilesScanControlBar(viewModel: LargeFilesViewModel())
        .padding()
}

