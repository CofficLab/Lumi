import SwiftUI

/// 语言选择器：下拉菜单选择 AI 响应语言
struct LanguageSelector: View {
    @EnvironmentObject var projectViewModel: ProjectViewModel

    /// 图标尺寸常量
    private let iconSize: CGFloat = 14

    var body: some View {
        Menu {
            ForEach(LanguagePreference.allCases) { lang in
                Button(action: {
                    withAnimation {
                        projectViewModel.setLanguagePreference(lang)
                    }
                }) {
                    HStack {
                        Text(lang.displayName)
                        if projectViewModel.languagePreference == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: iconSize))
                Text(projectViewModel.languagePreference.displayName)
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 70)
    }
}

// MARK: - Preview

#Preview("Language Selector") {
    LanguageSelector()
        .padding()
        .background(Color.black)
        .inRootView()
}
