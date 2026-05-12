#if canImport(LumiPreviewKit)
import SwiftUI

/// 编辑器预览显示模式切换器。
///
/// 提供 Image / Live 两个标签页，用户可切换预览渲染方式。
/// Live 模式在不可用时显示禁用状态和原因。
struct EditorPreviewDisplayModePickerView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel

    var body: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.switchToImage()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "photo")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(localized: "Image", table: "EditorPreview"))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.displayMode == .image
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(
                    viewModel.displayMode == .image
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor()
                )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.2))
                .frame(width: 1, height: 14)

            Button {
                if viewModel.canSwitchToLive {
                    viewModel.switchToLive()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: viewModel.displayMode == .live ? "play.rectangle.fill" : "play.rectangle")
                        .font(.system(size: 9, weight: .medium))
                    Text(String(localized: "Live", table: "EditorPreview"))
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.displayMode == .live
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(liveTabColor)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSwitchToLive && viewModel.displayMode != .live)
            .help(viewModel.liveUnavailableReason ?? String(localized: "Switch to Live mode", table: "EditorPreview"))
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.15), lineWidth: 0.5)
        )
    }

    private var liveTabColor: Color {
        if viewModel.displayMode == .live {
            return .green
        }
        if viewModel.canSwitchToLive {
            return themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
        return themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.5)
    }
}
#endif
