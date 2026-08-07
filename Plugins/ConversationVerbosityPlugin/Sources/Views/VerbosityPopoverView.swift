import LumiKernel
import SwiftUI

struct VerbosityPopover: View {
    let selectedLevel: LumiResponseVerbosity
    /// 当前操作对象是否为某个对话（true）还是全局设置（false）
    let isConversationScope: Bool
    let onSelect: (LumiResponseVerbosity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isConversationScope
                 ? LumiPluginLocalization.string("Conversation Verbosity", bundle: .module)
                 : LumiPluginLocalization.string("Global Verbosity", bundle: .module))
                .font(.system(size: 12, weight: .semibold))

            ForEach(LumiResponseVerbosity.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    VerbosityRow(level: level, isSelected: level == selectedLevel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 280)
    }
}
