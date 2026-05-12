#if canImport(LumiPreviewKit)
import SwiftUI

/// 编辑器预览工具栏。
///
/// 展示预览标题、当前文件名、显示模式切换（Image/Live）
/// 以及播放/刷新/停止按钮。
struct EditorPreviewToolbarView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel
    let currentFileURL: URL?
    @State private var isShowingDiagnostics = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text(String(localized: "Editor Preview", table: "EditorPreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let currentFileURL {
                Text(currentFileURL.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 0)

            EditorPreviewDisplayModePickerView(viewModel: viewModel)

            EditorPreviewCanvasPresetPickerView(viewModel: viewModel)

            EditorPreviewCanvasScalePickerView(viewModel: viewModel)

            EditorPreviewStatusBadgeView(viewModel: viewModel)

            Button {
                isShowingDiagnostics.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help(String(localized: "Preview diagnostics", table: "EditorPreview"))
            .popover(isPresented: $isShowingDiagnostics, arrowEdge: .bottom) {
                EditorPreviewDiagnosticPopoverView(viewModel: viewModel)
            }

            Button {
                viewModel.startSelectedPreview()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStart)
            .help(String(localized: "Start preview", table: "EditorPreview"))

            Button {
                viewModel.refreshPreview()
            } label: {
                if viewModel.isUpdatingPreview {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.55)
                        .frame(width: 13, height: 13)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRefresh)
            .help(String(localized: "Refresh preview", table: "EditorPreview"))

            Button {
                viewModel.stopPreview()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStop)
            .help(String(localized: "Stop preview", table: "EditorPreview"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }
}

private struct EditorPreviewCanvasPresetPickerView: View {
    @ObservedObject var viewModel: EditorPreviewViewModel

    var body: some View {
        Menu {
            ForEach(EditorPreviewViewModel.CanvasSizePreset.allCases) { preset in
                Button {
                    viewModel.setCanvasSizePreset(preset)
                } label: {
                    HStack {
                        Text(preset.title)
                        if viewModel.canvasSizePreset == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.resize")
                    .font(.system(size: 11, weight: .medium))
                Text(viewModel.canvasSizePreset.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(String(localized: "Canvas size", table: "EditorPreview"))
    }
}

private struct EditorPreviewCanvasScalePickerView: View {
    @ObservedObject var viewModel: EditorPreviewViewModel

    var body: some View {
        Picker(String(localized: "Canvas scale", table: "EditorPreview"), selection: selection) {
            Text(String(localized: "Fit", table: "EditorPreview")).tag("fit")
            Text("100%").tag("1.0")
            Text("75%").tag("0.75")
            Text("50%").tag("0.5")
        }
        .pickerStyle(.segmented)
        .frame(width: 168)
        .help(String(localized: "Canvas scale", table: "EditorPreview"))
    }

    private var selection: Binding<String> {
        Binding(
            get: {
                if viewModel.isCanvasScaleToFit { return "fit" }
                return String(format: "%.2g", viewModel.canvasScale)
            },
            set: { value in
                if value == "fit" {
                    viewModel.setCanvasScaleToFit()
                } else if let scale = Double(value) {
                    viewModel.setCanvasScale(CGFloat(scale))
                }
            }
        )
    }
}

private struct EditorPreviewDiagnosticPopoverView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Preview Diagnostics", table: "EditorPreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            Text(viewModel.diagnosticSummary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: 360, alignment: .leading)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }
}

/// 编辑器预览运行状态徽标。
///
/// 根据预览运行状态显示不同颜色和文本标签（运行中/失败/停止等），
/// 更新阶段时显示加载指示器。
struct EditorPreviewStatusBadgeView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel

    var body: some View {
        HStack(spacing: 5) {
            if viewModel.isUpdatingPreview {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.55)
                    .frame(width: 12, height: 12)
            }
            Text(statusTitle)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(statusColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private var statusTitle: String {
        if viewModel.isUpdatingPreview {
            viewModel.updatePhase.title
        } else {
            viewModel.runState.title
        }
    }

    private var statusColor: Color {
        if viewModel.isUpdatingPreview {
            return .orange
        }
        switch viewModel.runState {
        case .running:
            return .green
        case .failed, .hostMissing:
            return .red
        case .starting:
            return .orange
        case .idle, .stopped:
            return themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
    }
}
#endif
