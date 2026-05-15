import SwiftUI

/// 目录结构分析控制栏
struct DirectoryTreeScanControlBar: View {
    @ObservedObject var viewModel: DirectoryTreeViewModel

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
                    title: { Text(viewModel.isScanning ? String(localized: "停止分析", table: "DiskManager") : String(localized: "分析目录", table: "DiskManager")) },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "folder.badge.gear") }
                )
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? Color(hex: "FF453A") : Color(hex: "7C6FFF"))

            Spacer()

            Text(String(localized: "扫描目录：用户主目录", table: "DiskManager"))
                .font(.caption)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
        }
        .padding(.horizontal)
    }
}

#Preview {
    DirectoryTreeScanControlBar(viewModel: DirectoryTreeViewModel())
        .padding()
}

