import Foundation
import LumiUI
import SwiftUI

/// 模型选择弹窗：左侧供应商列表 + 右侧模型列表（由旧版复刻）。
///
/// View 只依赖 `ModelSelectorViewModel`，不持有 Provider/Store/Observer。
struct PopoverContent: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ModelSelectorViewModel
    @Binding var isPresented: Bool

    init(viewModel: ModelSelectorViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Provider List
            ProviderListView(
                viewModel: viewModel,
                onClose: { isPresented = false }
            )
            .frame(width: 300)

            AppDivider(.vertical)

            // Right: Model List for selected provider
            ModelListView(
                viewModel: viewModel,
                onSelect: { _, _ in
                    isPresented = false
                }
            )
        }
        .frame(width: 780, height: 600)
    }
}
