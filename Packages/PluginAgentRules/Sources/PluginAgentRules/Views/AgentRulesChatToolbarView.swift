import SwiftUI

/// Chat 工具栏规则入口：显示可用规则数量，点击弹出列表。
///
/// 样式与 ``SkillChatToolbarView`` 保持一致。
struct AgentRulesChatToolbarView: View {
    @ObservedObject var viewModel: AgentRulesToolbarViewModel

    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10, weight: .medium))

                if !viewModel.rules.isEmpty {
                    Text("\(viewModel.rules.count)")
                        .font(.system(size: 10, weight: .medium))
                        .contentTransition(.numericText())
                } else {
                    Text(LumiPluginLocalization.string("Rules", bundle: .module))
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(Color.accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Color.accentColor.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(Text(viewModel.rules.isEmpty ? "无可用规则" : "\(viewModel.rules.count) 个可用规则"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            AgentRulesListView(viewModel: viewModel)
                .frame(width: 360)
                .frame(minHeight: 220, maxHeight: 480)
        }
    }
}
