import SwiftUI
import MagicKit

/// 大文件列表视图
struct LargeFilesListView: View {
    @ObservedObject var viewModel: DiskManagerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            if viewModel.largeFiles.isNotEmpty {
                ScanControlBar(forLargeFiles: viewModel)
            }

            VStack {
                // 扫描进度
                if viewModel.isScanning {
                    ScanProgressView(viewModel: viewModel)
                }

                // 错误消息
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(DesignTokens.Color.semantic.error)
                        .padding()
                }

                // 文件列表
                if viewModel.largeFiles.isEmpty && !viewModel.isScanning {
                    EmptyLargeFilesView(viewModel: viewModel)
                } else if !viewModel.isScanning {
                    List {
                        ForEach(viewModel.largeFiles) { file in
                            LargeFileRow(item: file, viewModel: viewModel)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - 预览

#Preview {
    LargeFilesListView(viewModel: DiskManagerViewModel())
}
