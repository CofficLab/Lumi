import LumiKernel
import LumiLocalizationKit
import LumiUI
import SwiftUI

/// Displays a fatal error screen when the app cannot continue running.
///
/// 所有视觉元素均来自 LumiUI(`@LumiTheme` / `AppCard` / `GlassKeyValueRow` /
/// `AppButton`),保证崩溃屏与正常界面在主题(深浅色 / accent)下观感一致。
struct CrashedView: View {
    @LumiTheme private var theme

    var error: Error

    @State private var isCopied = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppUI.Spacing.lg) {
                Spacer(minLength: AppUI.Spacing.xl)

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
            .padding(.horizontal, AppUI.Spacing.xl)
            .padding(.bottom, AppUI.Spacing.xl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
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
        .padding(AppUI.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Radius.md, style: .continuous)
                .fill(theme.error.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Radius.md, style: .continuous)
                .stroke(theme.error.opacity(0.2), lineWidth: 1)
        )
    }

    private var debugView: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
            Text(LumiLocalization.string("Folders", bundle: .module))
                .font(.appSectionTitle)
                .foregroundStyle(theme.textSecondary)

            AppCard(style: .subtle, cornerRadius: AppUI.Radius.md, padding: AppUI.Spacing.compactPadding) {
                // 崩溃屏自身不能 throw(否则崩溃屏二次崩溃)。
                // makeDataRootDirectory() 已改为 throws,此处用 try? 降级;
                // 解析失败时显示占位符,恰好说明环境异常。
                GlassKeyValueRow(
                    label: LumiLocalization.string("App Support", bundle: .module),
                    value: makeDataRootDirectory()?.path(percentEncoded: false) ?? "(unavailable)"
                )
            }

            AppCard(style: .subtle, cornerRadius: AppUI.Radius.md, padding: AppUI.Spacing.cardPadding) {
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

    nonisolated static func errorDetailsText(_ error: Error) -> String {
        """
        Error type: \(String(describing: type(of: error)))
        Error description: \(error.localizedDescription)
        """
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("CrashedView") {
        CrashedView(
            error: NSError(
                domain: "TestError",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "This is a test error for preview purposes"]
            )
        )
    }

    #Preview("CrashedView - Force Cast Error") {
        CrashedView(
            error: NSError(
                domain: "com.coffic.lumi.bootstrap",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not cast LumiCore.chatService to ChatService. Make sure LumiCore.setupChatBootstrap was called."]
            )
        )
    }
#endif
