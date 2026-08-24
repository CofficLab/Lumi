import AppKit
import Foundation

/// Minimal native theme snapshot for message rendering.
///
/// Task 9 uses the system default; Task 14 snapshots the LumiUI theme store
/// into this struct and bumps `revision` so layout-cache keys invalidate.
/// `revision` participates in `AppKitRowLayoutKey`.
@MainActor
public struct AppKitMessageTheme {
    public let revision: Int

    public let bodyFont: NSFont
    public let headingFonts: [Int: NSFont]
    public let codeFont: NSFont
    public let textColor: NSColor
    public let secondaryTextColor: NSColor
    public let linkColor: NSColor
    public let quoteColor: NSColor
    public let codeBackgroundColor: NSColor

    public init(
        revision: Int,
        bodyFont: NSFont,
        headingFonts: [Int: NSFont],
        codeFont: NSFont,
        textColor: NSColor,
        secondaryTextColor: NSColor,
        linkColor: NSColor,
        quoteColor: NSColor,
        codeBackgroundColor: NSColor
    ) {
        self.revision = revision
        self.bodyFont = bodyFont
        self.headingFonts = headingFonts
        self.codeFont = codeFont
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.linkColor = linkColor
        self.quoteColor = quoteColor
        self.codeBackgroundColor = codeBackgroundColor
    }

    public static func systemDefault(revision: Int = 0) -> AppKitMessageTheme {
        AppKitMessageTheme(
            revision: revision,
            bodyFont: .systemFont(ofSize: 13),
            headingFonts: [
                1: .systemFont(ofSize: 20, weight: .semibold),
                2: .systemFont(ofSize: 17, weight: .semibold),
                3: .systemFont(ofSize: 15, weight: .semibold),
                4: .systemFont(ofSize: 14, weight: .semibold),
                5: .systemFont(ofSize: 13, weight: .semibold),
                6: .systemFont(ofSize: 13, weight: .semibold),
            ],
            codeFont: .monospacedSystemFont(ofSize: 12, weight: .regular),
            textColor: .labelColor,
            secondaryTextColor: .secondaryLabelColor,
            linkColor: .linkColor,
            quoteColor: .secondaryLabelColor,
            codeBackgroundColor: NSColor(white: 0.5, alpha: 0.12)
        )
    }
}
