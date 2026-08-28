import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import KitMarkdown
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
            // 列表需要比普通块间距更松,避免连续条目粘成一团。
            listItemSpacing: 8,
            textColor: theme.textPrimary,
            secondaryTextColor: theme.textSecondary
        )
    }
}
