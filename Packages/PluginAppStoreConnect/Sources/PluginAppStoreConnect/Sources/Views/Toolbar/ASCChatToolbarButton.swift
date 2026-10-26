import LumiUI
import SwiftUI

/// Chat Toolbar 上的 App Store Connect 胶囊按钮。
///
/// 视觉风格对齐 `GitChatToolbarButton`：图标 + 计数徽标，点击弹出
/// ``ASCChatToolbarPopoverView`` 展示当前项目对应 App 的版本列表。
struct ASCChatToolbarButton: View {
    @ObservedObject var viewModel: ASCChatToolbarViewModel
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            label
        }
        .buttonStyle(.plain)
        .help(AppStoreConnectLocalization.string("App Store Connect versions for this project"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ASCChatToolbarPopoverView(viewModel: viewModel)
        }
        .onChange(of: viewModel.projectPath) { _, _ in
            // 项目切换：关闭弹层避免显示旧项目的版本数据。
            isPopoverPresented = false
        }
    }

    // MARK: - Label

    private var label: some View {
        HStack(spacing: 3) {
            Image(systemName: "shippingbox")
                .font(.system(size: 10, weight: .medium))

            Text("\(viewModel.versionCount)")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundColor(tintColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            tintColor.opacity(0.22),
            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
        )
    }

    private var tintColor: Color {
        if viewModel.errorMessage != nil { return .orange }
        return Color.accentColor
    }
}
