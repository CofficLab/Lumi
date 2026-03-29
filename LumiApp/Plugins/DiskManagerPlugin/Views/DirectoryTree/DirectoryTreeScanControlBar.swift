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
                    title: { Text(viewModel.isScanning ? "停止分析" : "分析目录") },
                    icon: { Image(systemName: viewModel.isScanning ? "stop.circle" : "folder.badge.gear") }
                )
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            })
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isScanning ? AppUI.Color.semantic.error : AppUI.Color.semantic.primary)

            Spacer()

            Text("扫描目录：用户主目录")
                .font(.caption)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    DirectoryTreeScanControlBar(viewModel: DirectoryTreeViewModel())
        .padding()
}

