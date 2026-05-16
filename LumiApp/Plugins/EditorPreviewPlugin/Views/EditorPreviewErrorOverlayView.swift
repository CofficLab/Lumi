import LumiPreviewKit
import SwiftUI

/// Canvas 上叠加的错误浮层视图。
///
/// 当预览失败时显示标题、错误描述及完整诊断详情；内容区可滚动，底部复制操作栏固定。
struct HotPreviewErrorOverlayView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let title: String
    let message: String
    var contextInfo: String?
    var isOverlayingStaleFrame: Bool = false
    var viewModel: EditorRemoteHotPreviewViewModel? = nil

    @State private var didCopy = false

    private let scrollMaxHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    detailSection
                }
            }
            .frame(maxHeight: scrollMaxHeight)

            actionBar
        }
        .frame(maxWidth: 420)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(primaryTextColor)
            }

            Text(message)
                .font(.system(size: 11))
                .foregroundColor(secondaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 0)
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 6)

            detailContent
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let viewModel {
            viewModelDetailRows(viewModel)
        } else if let contextInfo {
            Text(contextInfo)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(tertiaryTextColor)
                .textSelection(.enabled)
        }
    }

    private func viewModelDetailRows(_ viewModel: EditorRemoteHotPreviewViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let contextInfo {
                compactInfoRow(contextInfo)
            }

            compactKVRow("Frame", viewModel.lastFrameSummary)

            if let performanceSummary = viewModel.performanceSummary {
                compactKVRow("Performance", performanceSummary)
            }

            compactKVRow("Live", localizedLiveState(viewModel.livePreviewInfo.state))
            compactKVRow("Display", localizedDisplayMode(viewModel.effectiveDisplayMode))
            compactKVRow("Transport", viewModel.transportSummary)
            compactKVRow("Host", viewModel.hostState.title)

            if let liveReason = viewModel.livePreviewInfo.unavailableReason, !liveReason.isEmpty {
                compactKVRow("Live Error", liveReason, isHighlight: true)
            }

            if let diagnostics = viewModel.diagnostics, !diagnostics.isEmpty {
                compactKVRow("Diagnostics", diagnostics, isHighlight: true)
            }

            if let failureMessage = viewModel.failureMessage {
                compactKVRow("Failure", failureMessage, isHighlight: true)
            }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            copyButton
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    private var copyButton: some View {
        Button {
            copyErrorToClipboard()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 8, weight: .medium))
                Text(didCopy
                    ? String(localized: "Copied", table: "EditorPreview")
                    : String(localized: "Copy", table: "EditorPreview"))
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(didCopy ? .green : tertiaryTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func compactKVRow(
        _ key: String,
        _ value: String,
        isHighlight: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(tertiaryTextColor)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(isHighlight ? .orange.opacity(0.9) : secondaryTextColor.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private func compactInfoRow(_ info: String) -> some View {
        Text(info)
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(tertiaryTextColor)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    // MARK: - Colors

    private var primaryTextColor: Color {
        isOverlayingStaleFrame ? .white.opacity(0.9) : themeVM.activeAppTheme.workspaceTextColor()
    }

    private var secondaryTextColor: Color {
        isOverlayingStaleFrame
            ? .white.opacity(0.7)
            : themeVM.activeAppTheme.workspaceSecondaryTextColor()
    }

    private var tertiaryTextColor: Color {
        isOverlayingStaleFrame
            ? .white.opacity(0.45)
            : themeVM.activeAppTheme.workspaceTertiaryTextColor()
    }

    private var background: some View {
        Group {
            if isOverlayingStaleFrame {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())
            }
        }
    }

    private var borderColor: Color {
        isOverlayingStaleFrame ? .orange : themeVM.activeAppTheme.workspaceTertiaryTextColor()
    }

    // MARK: - Localization

    private func localizedLiveState(_ state: LumiPreviewFacade.LivePreviewState) -> String {
        switch state {
        case .unavailable: String(localized: "Unavailable", table: "EditorPreview")
        case .available: String(localized: "Available", table: "EditorPreview")
        case .launching: String(localized: "Launching", table: "EditorPreview")
        case .running: String(localized: "Running", table: "EditorPreview")
        case .failed: String(localized: "Failed", table: "EditorPreview")
        case .stopped: String(localized: "Stopped", table: "EditorPreview")
        }
    }

    private func localizedDisplayMode(_ mode: LumiPreviewFacade.PreviewDisplayMode) -> String {
        switch mode {
        case .image: String(localized: "Image", table: "EditorPreview")
        case .live: String(localized: "Live", table: "EditorPreview")
        }
    }

    // MARK: - Copy

    private func copyErrorToClipboard() {
        var parts = ["[\(title)]", message]
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
        } else if let contextInfo {
            parts.append("")
            parts.append(contextInfo)
        }
        let fullText = parts.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullText, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                didCopy = false
            }
        }
    }
}
