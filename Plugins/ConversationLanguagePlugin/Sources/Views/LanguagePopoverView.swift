import KernelLumi
import SwiftUI

struct LanguagePopover: View {
    let selectedLanguage: LumiConversationLanguage
    /// 当前操作对象是否为某个对话（true）还是全局设置（false）
    let isConversationScope: Bool
    let onSelect: (LumiConversationLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isConversationScope
                 ? LumiPluginLocalization.string("Conversation Language", bundle: .module)
                 : LumiPluginLocalization.string("Global Language", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            ForEach(LumiConversationLanguage.allCases) { language in
                Button {
                    onSelect(language)
                } label: {
                    LanguageRow(language: language, isSelected: language == selectedLanguage)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 280)
    }
}
