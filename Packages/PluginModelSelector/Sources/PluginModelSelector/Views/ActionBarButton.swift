import LumiUI
import SwiftUI

/// Action Bar 上的模型选择按钮（由旧版 ModelSelectorPlugin 复刻）。
///
/// View 只依赖 `ModelSelectorViewModel`；Provider/模型目录与用量变化由
/// ViewModel 内部订阅，按钮标签实时反映「供应商 · 模型」。
struct ActionBarButton: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModel: ModelSelectorViewModel

    @State private var isPopoverPresented = false

    init(viewModel: ModelSelectorViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.appCallout)
                Text(viewModel.buttonLabel)
                    .font(.appCaptionEmphasized)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(theme.appStatusMutedFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            PopoverContent(
                viewModel: viewModel,
                isPresented: $isPopoverPresented
            )
        }
        .accessibilityLabel("Select Model")
    }
}
