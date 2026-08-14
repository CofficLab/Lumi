import SwiftUI
import KernelLumi

/// 原型设计器主视图：左侧对话区 + 右侧实时预览区，可拖拽调整宽度。
struct PrototypeDesignerView: View {
    private let kernel: KernelLumi
    @State private var viewModel: PrototypeDesignerViewModel

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _viewModel = State(initialValue: PrototypeDesignerViewModel(kernel: kernel))
    }

    var body: some View {
        HSplitView {
            ChatColumn(viewModel: viewModel)
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 600)

            PreviewColumn(viewModel: viewModel)
                .frame(minWidth: 360, idealWidth: 560, maxWidth: .infinity)
        }
    }
}
