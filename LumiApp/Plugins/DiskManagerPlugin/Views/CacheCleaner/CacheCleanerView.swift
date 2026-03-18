import SwiftUI

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
            if viewModel.categories.isEmpty {
                viewModel.scan()
            }
        }
        .alert(Text("Confirm Cleanup"), isPresented: $showCleanConfirmation) {
            Button(role: .destructive) {
                viewModel.cleanSelected()
            } label: {
                Text("Clean")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel")
            }
        } message: {
            Text("Are you sure you want to clean the selected \(viewModel.formatBytes(viewModel.totalSelectedSize)) files? This action cannot be undone.")
        }
        .alert(Text("Cleanup Complete"), isPresented: $viewModel.showCleanupComplete) {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        } message: {
            Text("Successfully freed \(viewModel.formatBytes(viewModel.lastFreedSpace)) space.")
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
