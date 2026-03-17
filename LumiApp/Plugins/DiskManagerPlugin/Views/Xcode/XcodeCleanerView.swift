import SwiftUI
import AppKit

struct XcodeCleanerView: View {
    @StateObject private var viewModel = XcodeCleanerViewModel()
    @State private var showCleanConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // 扫描控制区域
            if !viewModel.itemsByCategory.isEmpty && !viewModel.isScanning {
                XcodeScanControlBar(viewModel: viewModel)
            }

            VStack {
                // 扫描进度
                if viewModel.isScanning {
                    XcodeScanProgressView(viewModel: viewModel)
                }

                // 内容列表
                if viewModel.itemsByCategory.isEmpty && !viewModel.isScanning {
                    XcodeEmptyStateView(viewModel: viewModel)
                } else if !viewModel.isScanning {
                    List {
                        ForEach(XcodeCleanCategory.allCases) { category in
                            if let items = viewModel.itemsByCategory[category], !items.isEmpty {
                                XcodeCategorySection(category: category, items: items, viewModel: viewModel)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxHeight: .infinity)

            // 底部操作栏
            if !viewModel.isScanning {
                XcodeCleanerFooter(viewModel: viewModel, showCleanConfirmation: $showCleanConfirmation)
            }
        }
        .onAppear {
            Task { await viewModel.scanAll() }
        }
        .alert(Text("Confirm Cleanup"), isPresented: $showCleanConfirmation) {
            Button(role: .cancel) {} label: {
                Text("Cancel")
            }
            Button(role: .destructive) {
                Task { await viewModel.cleanSelected() }
            } label: {
                Text("Clean")
            }
        } message: {
            let template = String(
                localized: "Are you sure you want to clean %@ of Xcode cache? This action cannot be undone.",
                table: "DiskManager"
            )
            Text(String(format: template, viewModel.formatBytes(viewModel.selectedSize)))
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
