import SwiftUI

/// 空消息视图 - 已选择会话但没有消息时显示
struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            // 标题
            Text("暂无消息", tableName: "DevAssistant")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text("在下方输入框中输入您的问题，开始与 AI 助手对话", tableName: "DevAssistant")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    EmptyMessagesView()
        .frame(width: 600, height: 400)
}
