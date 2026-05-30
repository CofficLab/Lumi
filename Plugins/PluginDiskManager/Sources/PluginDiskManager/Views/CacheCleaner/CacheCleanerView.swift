import SwiftUI
import DiskManagerKit

struct CacheCleanerView: View {
    @StateObject private var viewModel = CacheCleanerViewModel()
    @State private var showCleanConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            if viewModel.categories.isEmpty == false && viewModel.isScanning == false {
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
        .alert(Text(PluginDiskManagerLocalization.string("Confirm Cleanup")), isPresented: $showCleanConfirmation) {
            Button(role: .destructive) {
                viewModel.cleanSelected()
            } label: {
                Text(PluginDiskManagerLocalization.string("Clean"))
            }
            Button(role: .cancel) {} label: {
                Text(PluginDiskManagerLocalization.string("Cancel"))
            }
        } message: {
            Text(String(format: PluginDiskManagerLocalization.string("Are you sure you want to clean the selected %@ files? This action cannot be undone."), viewModel.formatBytes(viewModel.totalSelectedSize)))
        }
        .alert(Text(PluginDiskManagerLocalization.string("Cleanup Complete")), isPresented: $viewModel.showCleanupComplete) {
            Button(role: .cancel) {} label: {
                Text(PluginDiskManagerLocalization.string("OK"))
            }
        } message: {
            Text(String(format: PluginDiskManagerLocalization.string("Successfully freed %@ space."), viewModel.formatBytes(viewModel.lastFreedSpace)))
        }
        .alert(
            Text(PluginDiskManagerLocalization.string("Cleanup Failed")),
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.alertMessage = nil
                    }
                }
            )
        ) {
            Button(role: .cancel) {} label: {
                Text(PluginDiskManagerLocalization.string("OK"))
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}
