import LumiUI
import MarkdownKit
import SwiftUI

enum ChatMarkdownTheme {
    static func make(from theme: any LumiUITheme) -> MarkdownTheme {
        MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 17, weight: .semibold)
                case 2: return .system(size: 16, weight: .semibold)
                case 3: return .system(size: 15, weight: .semibold)
                default: return .system(size: 14, weight: .semibold)
                }
            },
            bodyFont: .system(size: 14),
            textColor: theme.textPrimary,
            secondaryTextColor: theme.textSecondary
        )
    }
}
