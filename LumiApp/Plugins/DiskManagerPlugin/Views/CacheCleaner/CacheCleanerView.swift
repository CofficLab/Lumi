import SwiftUI
import DiskManagerKit

struct CacheCleanerView: View {
    @StateObject private var viewModel = CacheCleanerViewModel()
    @State private var showCleanConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            if viewModel.categories.isNotEmpty && viewModel.isScanning == false {
                CacheScanControlBar(viewModel: viewModel)
            }

            VStack {
                // 扫描进度
                if viewModel.isScanning {
                    CacheScanProgressView(viewModel: viewModel)
                }

                // 内容列表
                if viewModel.categories.isEmpty && !viewModel.isScanning {
                    EmptyCacheView(viewModel: viewModel)
                } else if !viewModel.isScanning {
                    List {
                        ForEach(viewModel.categories) { category in
                            CacheCategorySection(category: category, viewModel: viewModel)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxHeight: .infinity)

            // 底部操作栏
            if !viewModel.selection.isEmpty && !viewModel.isScanning {
                CacheCleanerFooter(viewModel: viewModel, showCleanConfirmation: $showCleanConfirmation)
            }
        }
        .onAppear {
            viewModel.scanIfNeeded()
        }
        .alert(Text(String(localized: "Confirm Cleanup", table: "DiskManager")), isPresented: $showCleanConfirmation) {
            Button(role: .destructive) {
                viewModel.cleanSelected()
            } label: {
                Text(String(localized: "Clean", table: "DiskManager"))
            }
            Button(role: .cancel) {} label: {
                Text(String(localized: "Cancel", table: "DiskManager"))
            }
        } message: {
            Text(String(format: String(localized: "Are you sure you want to clean the selected %@ files? This action cannot be undone.", table: "DiskManager"), viewModel.formatBytes(viewModel.totalSelectedSize)))
        }
        .alert(Text(String(localized: "Cleanup Complete", table: "DiskManager")), isPresented: $viewModel.showCleanupComplete) {
            Button(role: .cancel) {} label: {
                Text(String(localized: "OK", table: "DiskManager"))
            }
        } message: {
            Text(String(format: String(localized: "Successfully freed %@ space.", table: "DiskManager"), viewModel.formatBytes(viewModel.lastFreedSpace)))
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
