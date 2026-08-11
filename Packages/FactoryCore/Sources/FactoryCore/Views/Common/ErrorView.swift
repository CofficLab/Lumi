import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

/// Displays an error message when the app encounters a fatal error.
///
/// 所有视觉元素均来自 LumiUI(`@LumiTheme` / `AppCard` / `GlassKeyValueRow` /
/// `AppButton` / `DesignTokens`),保证错误界面与正常界面在主题(深浅色 / accent)下观感一致。
public struct ErrorView: View {
    @LumiTheme private var theme

    public var error: Error

    @State private var isCopied = false

    public init(error: Error) {
        self.error = error
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer(minLength: DesignTokens.Spacing.xl)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(theme.error)
                    .scaledToFit()
                    .frame(maxHeight: 120)

                Text(LumiLocalization.string("Unable to continue", bundle: .module))
                    .font(.appTitle)
                    .foregroundStyle(theme.textPrimary)

                errorCard

                debugView

                #if os(macOS)
                    AppButton(
                        LumiLocalization.string("Quit", bundle: .module),
                        systemImage: "power",
                        style: .primary,
                        size: .medium
                    ) {
                        NSApplication.shared.terminate(self)
                    }

                    Spacer()
                #endif
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(String(describing: type(of: error)))
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)

            Text(error.localizedDescription)
                .font(.appCallout)
                .foregroundStyle(theme.error)
                .textSelection(.enabled)

            CopyMessageButton(
                content: Self.errorDetailsText(error),
                showFeedback: $isCopied
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(theme.error.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(theme.error.opacity(0.2), lineWidth: 1)
        )
    }

    private var debugView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(LumiLocalization.string("Folders", bundle: .module))
                .font(.appSectionTitle)
                .foregroundStyle(theme.textSecondary)

            AppCard(style: .subtle, cornerRadius: DesignTokens.Radius.md, padding: DesignTokens.Spacing.compactPadding) {
                GlassKeyValueRow(
                    label: LumiLocalization.string("App Support", bundle: .module),
                    value: makeDataRootDirectory()?.path(percentEncoded: false) ?? "(unavailable)"
                )
            }

            AppCard(style: .subtle, cornerRadius: DesignTokens.Radius.md, padding: DesignTokens.Spacing.cardPadding) {
                Text(LumiLocalization.string(
                    "Please quit and reopen the app, or check logs for more details.",
                    bundle: .module
                ))
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func makeDataRootDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }

    nonisolated private static func errorDetailsText(_ error: Error) -> String {
        """
        Error type: \(String(describing: type(of: error)))
        Error description: \(error.localizedDescription)
        """
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("ErrorView") {
        ErrorView(
            error: NSError(
                domain: "TestError",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "This is a test error for preview purposes"]
            )
        )
    }

    #Preview("ErrorView - Kernel Error") {
        ErrorView(
            error: LumiKernelError.serviceNotAvailable(service: "LayoutManager")
        )
    }
#endif
