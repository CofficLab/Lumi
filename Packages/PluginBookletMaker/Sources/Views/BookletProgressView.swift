import LumiUI
import SwiftUI

// MARK: - Booklet Progress View

/// Progress bar + status text, shown while a render is in flight.
struct BookletProgressView: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: DesignTokens.Radius.sm,
            padding: DesignTokens.Spacing.compactPadding,
            showShadow: false
        ) {
            HStack {
                if viewModel.isRendering {
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(viewModel.progress * 100))%")
                        .font(DesignTokens.Typography.caption1.monospacedDigit())
                        .foregroundStyle(theme.textSecondary)
                } else if viewModel.isPreparingPreview {
                    ProgressView()
                    Text(BookletLocalization.string("Preparing preview…"))
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(theme.textSecondary)
                } else if viewModel.lastOutputURL != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                    Text(BookletLocalization.string("Export complete"))
                        .font(DesignTokens.Typography.subheadline)
                    Spacer()
                    AppButton(
                        BookletLocalization.string("Show in Finder"),
                        style: .ghost,
                        size: .small
                    ) {
                        if let url = viewModel.lastOutputURL {
                            viewModel.revealInFinder(url)
                        }
                    }
                } else if let error = viewModel.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.warning)
                    Text(error)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                } else {
                    Text(BookletLocalization.string("Ready"))
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
            }
        }
    }
}
