import SwiftUI

/// 空状态视图 - 未选择会话时显示
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // 标题
            Text("选择一个会话开始聊天", tableName: "DevAssistant")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text("从左侧列表选择一个现有会话，或创建新会话", tableName: "DevAssistant")
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
    EmptyStateView()
        .frame(width: 600, height: 400)
}
