import AgentToolKit
import SwiftUI
import MagicAlert

/// 语言切换按钮：点击循环切换中文/英文
///
/// 与 ChatModeToolbarButton 风格一致，点击即切换到下一种语言。
struct LanguageToggleButton: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 语言循环顺序
    private static let languageOrder: [LanguagePreference] = [.chinese, .english]

    var body: some View {
        Button(action: {
            let currentIndex = Self.languageOrder.firstIndex(of: projectVM.languagePreference) ?? 0
            let nextIndex = (currentIndex + 1) % Self.languageOrder.count
            let newLanguage = Self.languageOrder[nextIndex]
            withAnimation {
                projectVM.setLanguagePreference(newLanguage)
            }
            let title: String
            let subtitle: String
            switch newLanguage {
            case .chinese:
                title = "已切换为中文"
                subtitle = "AI 将使用中文回复"
            case .english:
                title = "Switched to English"
                subtitle = "AI will respond in English"
            }
            alert_info(title, subtitle: subtitle)
        }) {
            HStack(spacing: 4) {
                Image(systemName: projectVM.languagePreference.iconName)
                    .font(.system(size: 13))
                Text(projectVM.languagePreference.shortDisplayName)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    // MARK: - 计算属性

    private var foregroundColor: Color {
        switch projectVM.languagePreference {
        case .chinese:
            return Color.blue
        case .english:
            return Color.purple
        }
    }

    private var backgroundColor: Color {
        switch projectVM.languagePreference {
        case .chinese:
            return Color.blue.opacity(0.1)
        case .english:
            return Color.purple.opacity(0.1)
        }
    }

    private var helpText: String {
        switch projectVM.languagePreference {
        case .chinese:
            return "当前：中文，点击切换为英文"
        case .english:
            return "Current: English, click to switch to Chinese"
        }
    }
}

// MARK: - LanguagePreference UI Extensions

extension LanguagePreference {
    /// 工具栏按钮中显示的短名称
    var shortDisplayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "EN"
        }
    }

    /// 工具栏按钮图标
    var iconName: String {
        switch self {
        case .chinese: return "character.book.closed"
        case .english: return "textformat.abc"
        }
    }
}

#Preview("Language Toggle") {
    LanguageToggleButton()
        .padding()
        .inRootView()
}
