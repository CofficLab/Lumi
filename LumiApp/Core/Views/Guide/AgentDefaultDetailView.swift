import SwiftUI

/// Agent 模式下默认详情视图（当右侧栏无内容时显示）
struct AgentDefaultDetailView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("欢迎使用 Lumi")
                .font(AppUI.Typography.title3)
            Text("请从侧边栏选择一个导航入口")
                .font(AppUI.Typography.body)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
