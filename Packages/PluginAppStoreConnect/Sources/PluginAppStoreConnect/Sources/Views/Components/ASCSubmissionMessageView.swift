import LumiUI
import ProviderMessage
import SwiftUI

// MARK: - Submission Timeline View

/// App Store Connect 提交审核的结构化时间线消息视图。
///
/// 展示「当前将提交什么」：版本号、Build、平台、审核状态与本地化情况。
/// 载荷缺失时（历史数据或载荷损坏）回退到纯文本摘要，避免渲染空白。
struct ASCSubmissionMessageView: View {
    @LumiTheme private var theme

    let message: Message

    var body: some View {
        if let preview = ASCSubmissionTimeline.decodePreview(from: message.metadata) {
            card(preview)
        } else {
            fallback
        }
    }

    // MARK: - Card

    private func card(_ preview: ASCSubmissionPreview) -> some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header(preview)

                Divider()
                    .overlay(theme.divider.opacity(0.6))

                facts(preview)

                if !preview.localizations.isEmpty {
                    localizations(preview)
                }

                if preview.hasWarnings {
                    warnings(preview)
                }
            }
        }
    }

    // MARK: - Header

    private func header(_ preview: ASCSubmissionPreview) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: stageIcon(preview.stage))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(stageTint(preview.stage))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(stageTitle(preview.stage))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                if let appName = preview.appName, !appName.isEmpty {
                    Text(appName)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer(minLength: 8)

            Text(preview.platformLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.textSecondary.opacity(0.12))
                )
        }
    }

    // MARK: - Facts

    private func facts(_ preview: ASCSubmissionPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            factRow(
                icon: "number",
                title: L("Version"),
                value: preview.versionString
            )

            if let buildLabel = preview.buildDisplayLabel {
                factRow(
                    icon: "hammer",
                    title: L("Build"),
                    value: buildLabel,
                    trailing: buildStateLabel(preview)
                )
            } else {
                factRow(
                    icon: "hammer",
                    title: L("Build"),
                    value: L("Not assigned"),
                    tint: theme.warning
                )
            }

            factRow(
                icon: "flag",
                title: L("Status"),
                value: statusLabel(preview)
            )

            if let releaseType = preview.releaseType, !releaseType.isEmpty {
                factRow(
                    icon: "arrow.up.circle",
                    title: L("Release"),
                    value: releaseTypeLabel(releaseType)
                )
            }
        }
    }

    private func factRow(
        icon: String,
        title: String,
        value: String,
        trailing: String? = nil,
        tint: Color? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(tint ?? theme.textPrimary)

            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Localizations

    private func localizations(_ preview: ASCSubmissionPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AppSectionLabel(L("Localizations"))

            FlowRow(spacing: 6) {
                ForEach(preview.localizations, id: \.locale) { localization in
                    AppTag(localization.locale, systemImage: localization.isDescriptionEmpty ? "exclamationmark.triangle" : "checkmark.circle")
                }
            }
        }
    }

    // MARK: - Warnings

    private func warnings(_ preview: ASCSubmissionPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AppSectionLabel(L("Warnings"), color: theme.warning)

            ForEach(preview.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.warning)

                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Fallback

    private var fallback: some View {
        AppCard(style: .subtle, cornerRadius: 12) {
            Text(message.content)
                .font(.callout)
                .foregroundStyle(theme.textPrimary)
        }
    }

    // MARK: - Labels

    private func stageIcon(_ stage: ASCSubmissionStage) -> String {
        switch stage {
        case .preview: return "paperplane"
        case .submitted: return "checkmark.seal"
        case .failed: return "xmark.octagon"
        }
    }

    private func stageTint(_ stage: ASCSubmissionStage) -> Color {
        switch stage {
        case .preview: return theme.info
        case .submitted: return theme.success
        case .failed: return theme.error
        }
    }

    private func stageTitle(_ stage: ASCSubmissionStage) -> String {
        switch stage {
        case .preview: return L("Submitting for Review")
        case .submitted: return L("Submitted for Review")
        case .failed: return L("Submission Failed")
        }
    }

    private func statusLabel(_ preview: ASCSubmissionPreview) -> String {
        let state = preview.appStoreState.isEmpty ? "-" : preview.appStoreState
        if preview.appVersionState.isEmpty || preview.appVersionState == "-" {
            return state
        }
        return "\(state) · \(preview.appVersionState)"
    }

    private func buildStateLabel(_ preview: ASCSubmissionPreview) -> String? {
        guard let state = preview.buildProcessingState, !state.isEmpty else { return nil }
        if preview.buildExpired {
            return "\(state) · \(L("expired"))"
        }
        return state
    }

    private func releaseTypeLabel(_ releaseType: String) -> String {
        switch releaseType.uppercased() {
        case "AFTER_APPROVAL": return L("Automatic release")
        case "MANUAL": return L("Manual release")
        default: return releaseType
        }
    }

    private func L(_ key: String) -> String {
        AppStoreConnectLocalization.string(key, bundle: .module)
    }
}

// MARK: - FlowRow

/// 简易流式布局：把标签按行排列，超出宽度时自动换行。
///
/// LumiUI 暂未提供等价的流式容器，这里用一个轻量实现，
/// 避免本地化标签在窄侧栏里被截断。
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight
                maxRowWidth = max(maxRowWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth)
        return CGSize(width: min(maxRowWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ASCSubmissionMessageView(
            message: ASCSubmissionTimeline.message(
                conversationID: UUID(),
                turnID: nil,
                preview: ASCSubmissionPreview(
                    appName: "Lumi",
                    versionID: "v-1",
                    versionString: "1.2.0",
                    platform: "IOS",
                    platformLabel: "iOS",
                    appStoreState: "PREPARE_FOR_SUBMISSION",
                    appVersionState: "PREPARE_FOR_SUBMISSION",
                    releaseType: "AFTER_APPROVAL",
                    buildNumber: "45",
                    buildVersionString: "1.2.0",
                    buildProcessingState: "VALID",
                    localizations: [
                        ASCSubmissionLocalization(
                            locale: "en-US",
                            hasDescription: true,
                            hasWhatsNew: true,
                            hasKeywords: true,
                            isDescriptionEmpty: false
                        ),
                        ASCSubmissionLocalization(
                            locale: "zh-Hans",
                            hasDescription: false,
                            hasWhatsNew: true,
                            hasKeywords: true,
                            isDescriptionEmpty: true
                        )
                    ],
                    warnings: ["Localization 'zh-Hans' has an empty description. Update-localization to fill it in."]
                )
            )
        )
    }
    .padding(20)
    .frame(width: 420)
}
