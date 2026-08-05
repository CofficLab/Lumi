import SwiftUI

/// 应用管理器内容视图（右侧详情面板）。
///
/// 由 `AppManagerPlugin` 的 `ViewContainerItem` 注册，
/// 接收插件级 `sharedViewModel`，仅负责展示选中应用的详情。
struct AppManagerView: View {
    @ObservedObject var viewModel: AppManagerViewModel

    var body: some View {
        detailView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: viewModel.selectedApp) { _, newApp in
                if let app = newApp {
                    viewModel.scanRelatedFiles(for: app)
                } else {
                    viewModel.clearRelatedFiles()
                }
            }
    }

    private var detailView: some View {
        AppManagerDetailView(viewModel: viewModel)
    }
}
