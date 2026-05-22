import LumiUI
import SwiftUI

/// 语言选择器：下拉菜单选择 AI 响应语言
struct LanguageSelector: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject var projectVM: WindowProjectVM

    var body: some View {
        Menu {
            ForEach(LanguagePreference.allCases) { lang in
                Button(action: {
                    withAnimation {
                        projectVM.setLanguagePreference(lang)
                    }
                }) {
                    HStack {
                        Text(lang.displayName)
                        if projectVM.languagePreference == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.appCaptionEmphasized)
                Text(projectVM.languagePreference.displayName)
                    .font(.appCaption)
            }
            .foregroundColor(theme.textPrimary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 70)
    }
}

#Preview("Language Selector") {
    LanguageSelector()
        .padding()
        .background(Color.black)
        .inRootView()
}
