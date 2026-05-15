import LumiPreviewKit
import SwiftUI

/// Canvas 上叠加的错误浮层视图。
///
/// 当预览失败时显示结构化错误信息，包含错误类别、详细描述、可操作建议，
/// 以及可展开的完整诊断详情。
/// 可叠加在旧帧图片上方，用半透明背景保证可读性。
struct HotPreviewErrorOverlayView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    /// 错误标题
    let title: String

    /// 错误详细信息
    let message: String

    /// 上下文提示（如 Preview ID、Display Mode 等）
    var contextInfo: String?

    /// 可操作的建议文本
    var suggestion: String?

    /// 是否展示在旧帧上方（使用半透明背景）
    var isOverlayingStaleFrame: Bool = false

    /// 诊断信息的 ViewModel 引用，用于展示详细诊断
    var viewModel: EditorRemoteHotPreviewViewModel? = nil

    @State private var didCopy = false
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 10) {
            header
            messageSection
            if let contextInfo {
                contextSection(contextInfo)
            }
            if let suggestion {
                suggestionSection(suggestion)
            }
            if viewModel != nil {
                detailsToggle
                if showDetails {
                    diagnosticDetails
                }
            }
            actions
        }
        .padding(16)
        .frame(maxWidth: showDetails ? 440 : 360)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - 子视图

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.orange)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
            Spacer(minLength: 0)
        }
    }

    private var messageSection: some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private func contextSection(_ info: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(info)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.06))
        )
    }

    private func suggestionSection(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.orange.opacity(0.8))
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.orange.opacity(0.9))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailsToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                Text(showDetails
                    ? String(localized: "Hide Details", table: "EditorPreview")
                    : String(localized: "Show Details", table: "EditorPreview"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 可展开的诊断详情区域，包含原 Diagnostics Panel 的所有信息
    private var diagnosticDetails: some View {
        guard let viewModel else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 5) {
                Divider()

                infoRow(label: String(localized: "Frame", table: "EditorPreview"), value: viewModel.lastFrameSummary)

                if let performanceSummary = viewModel.performanceSummary {
                    infoRow(label: String(localized: "Performance", table: "EditorPreview"), value: performanceSummary)
                }

                infoRow(
                    label: String(localized: "Live", table: "EditorPreview"),
                    value: localizedLiveState(viewModel.livePreviewInfo.state)
                )
                infoRow(
                    label: String(localized: "Display", table: "EditorPreview"),
                    value: localizedDisplayMode(viewModel.effectiveDisplayMode)
                )
                infoRow(label: String(localized: "Transport", table: "EditorPreview"), value: viewModel.transportSummary)

                if let selectedPreviewID = viewModel.selectedPreviewID {
                    infoRow(
                        label: String(localized: "Preview ID", table: "EditorPreview"),
                        value: selectedPreviewID,
                        lineLimit: 2
                    )
                }

                infoRow(
                    label: String(localized: "Host", table: "EditorPreview"),
                    value: viewModel.hostState.title
                )

                if let modeStatusMessage = viewModel.modeStatusMessage {
                    infoRow(
                        label: String(localized: "Mode", table: "EditorPreview"),
                        value: modeStatusMessage,
                        color: .orange,
                        lineLimit: 4
                    )
                }

                if let renderMessage = viewModel.renderMessage {
                    infoRow(
                        label: String(localized: "Render", table: "EditorPreview"),
                        value: renderMessage,
                        lineLimit: 4
                    )
                }

                if let liveReason = viewModel.livePreviewInfo.unavailableReason, !liveReason.isEmpty {
                    infoRow(
                        label: String(localized: "Live Error", table: "EditorPreview"),
                        value: liveReason,
                        color: .orange,
                        lineLimit: 6
                    )
                }

                if let diagnostics = viewModel.diagnostics, !diagnostics.isEmpty {
                    infoRow(
                        label: String(localized: "Diagnostics", table: "EditorPreview"),
                        value: diagnostics,
                        color: .orange,
                        lineLimit: 8
                    )
                }

                if let failureMessage = viewModel.failureMessage {
                    infoRow(
                        label: String(localized: "Failure", table: "EditorPreview"),
                        value: failureMessage,
                        color: .red,
                        lineLimit: 6
                    )
                }

                if viewModel.previews.count > 1 {
                    let previewNames = viewModel.previews.map(\.title).joined(separator: ", ")
                    infoRow(
                        label: String(localized: "Previews", table: "EditorPreview"),
                        value: "\(viewModel.previews.count): \(previewNames)",
                        lineLimit: 3
                    )
                }

                Text(viewModel.diagnosticSummary)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                    .lineLimit(6)
                    .textSelection(.enabled)
            }
        )
    }

    private var actions: some View {
        HStack(spacing: 8) {
            copyButton
            Spacer(minLength: 0)
        }
    }

    private var copyButton: some View {
        Button {
            copyErrorToClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9, weight: .medium))
                Text(didCopy
                    ? String(localized: "Copied", table: "EditorPreview")
                    : String(localized: "Copy Details", table: "EditorPreview"))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(
                didCopy
                    ? .green
                    : themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.8)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 私有方法

    private func infoRow(
        label: String,
        value: String,
        color: Color? = nil,
        lineLimit: Int? = 2
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(color ?? themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .lineLimit(lineLimit ?? 2)
                .textSelection(.enabled)
        }
    }

    private var background: some View {
        Group {
            if isOverlayingStaleFrame {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.75))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())
            }
        }
    }

    private var borderColor: Color {
        isOverlayingStaleFrame ? .orange : themeVM.activeAppTheme.workspaceTertiaryTextColor()
    }

    private func localizedLiveState(_ state: LumiPreviewFacade.LivePreviewState) -> String {
        switch state {
        case .unavailable:
            String(localized: "Unavailable", table: "EditorPreview")
        case .available:
            String(localized: "Available", table: "EditorPreview")
        case .launching:
            String(localized: "Launching", table: "EditorPreview")
        case .running:
            String(localized: "Running", table: "EditorPreview")
        case .failed:
            String(localized: "Failed", table: "EditorPreview")
        case .stopped:
            String(localized: "Stopped", table: "EditorPreview")
        }
    }

    private func localizedDisplayMode(_ mode: LumiPreviewFacade.PreviewDisplayMode) -> String {
        switch mode {
        case .image:
            String(localized: "Image", table: "EditorPreview")
        case .live:
            String(localized: "Live", table: "EditorPreview")
        }
    }

    private func copyErrorToClipboard() {
        var parts = ["[\(title)]", message]
        if let contextInfo { parts.append(contextInfo) }
        if let suggestion { parts.append("💡 \(suggestion)") }
        if let viewModel {
            parts.append("")
            parts.append("Frame: \(viewModel.lastFrameSummary)")
            if let performanceSummary = viewModel.performanceSummary {
                parts.append("Performance: \(performanceSummary)")
            }
            parts.append("Live: \(localizedLiveState(viewModel.livePreviewInfo.state))")
            parts.append("Display: \(localizedDisplayMode(viewModel.effectiveDisplayMode))")
            parts.append("Transport: \(viewModel.transportSummary)")
            parts.append("Host: \(viewModel.hostState.title)")
            if let liveReason = viewModel.livePreviewInfo.unavailableReason {
                parts.append("Live Error: \(liveReason)")
            }
            if let diagnostics = viewModel.diagnostics {
                parts.append("Diagnostics: \(diagnostics)")
            }
            if let failureMessage = viewModel.failureMessage {
                parts.append("Failure: \(failureMessage)")
            }
            parts.append(viewModel.diagnosticSummary)
        }
        let fullText = parts.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullText, forType: .string)
        withAnimation(.easeInOut(duration: 0.2)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopy = false
            }
        }
    }
}
