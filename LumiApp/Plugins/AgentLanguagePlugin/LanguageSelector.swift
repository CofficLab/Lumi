import SwiftUI

/// 语言选择器：下拉菜单选择 AI 响应语言
struct LanguageSelector: View {
    @EnvironmentObject var projectVM: ProjectVM

    private let iconSize: CGFloat = 14

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
                    .font(.system(size: iconSize))
                Text(projectVM.languagePreference.displayName)
            }
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
