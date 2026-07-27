import LumiUI
import MarkdownKit
import SwiftUI

enum ChatMarkdownTheme {
    static func make(from theme: any LumiUITheme) -> MarkdownTheme {
        MarkdownTheme(
            textColor: theme.textPrimary,
            secondaryTextColor: theme.textSecondary
        )
    }
}
