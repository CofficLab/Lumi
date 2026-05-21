import LumiUI
import SwiftUI

/// 空消息视图 - 已选择会话但没有消息时显示
struct EmptyMessagesView: View {
    @EnvironmentObject private var WindowConversationVM: WindowConversationVM

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            AppCard(style: .elevated, padding: EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)) {
                VStack(spacing: 14) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text(String(localized: "No Messages", table: "AgentChat"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(String(localized: "No Messages Description", table: "AgentChat"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    examplesSection

                    QuickStartActionsView(sendStrategy: .sendInCurrentConversation)
                        .padding(.top, 4)

                    if let id = WindowConversationVM.selectedConversationId {
                        Text(id.uuidString)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 28)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "No Messages", table: "AgentChat"))
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppLabeledDivider(title: String(localized: "For Example", table: "AgentChat"))

            VStack(alignment: .leading, spacing: 6) {
                AppTag(
                    String(localized: "Example Error Log", table: "AgentChat"),
                    systemImage: "text.quote"
                )
                AppTag(
                    String(localized: "Example Test Plan", table: "AgentChat"),
                    systemImage: "checklist"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EmptyMessagesView()
        .frame(width: 600, height: 400)
        .inRootView()
}
