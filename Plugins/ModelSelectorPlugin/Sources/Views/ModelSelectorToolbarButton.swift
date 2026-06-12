import SwiftUI
import LumiCoreKit
import LumiUI

/// 模型选择器工具栏按钮
///
/// 显示当前供应商 + 模型名称，点击弹出 ModelSelectorView 的 Popover。
public struct ModelSelectorToolbarButton: View {
    let modelSelectionContext: ModelSelectionContext

    public init(modelSelectionContext: ModelSelectionContext) {
        self.modelSelectionContext = modelSelectionContext
    }

    public var body: some View {
        sidebarToolbarPopover(
            detailView: modelSelectionContext.detailView(),
            id: "model-selector"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 13))
                Text(modelSelectionContext.displayText)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .accessibilityLabel(LumiPluginLocalization.string("Select Model", bundle: .module))
        .accessibilityHint(LumiPluginLocalization.string("Select Model Hint", bundle: .module))
    }

}
