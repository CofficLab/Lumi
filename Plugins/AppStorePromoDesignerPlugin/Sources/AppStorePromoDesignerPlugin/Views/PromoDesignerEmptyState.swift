import SwiftUI

/// 设计师面板空态：未选中图像时提示用户通过 Agent 创建任务。
struct PromoDesignerEmptyState: View {
    let message: String

    // MARK: - 初始化

    init(message: String) {
        self.message = message
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 预览

#Preview {
    PromoDesignerEmptyState(
        message: "Ask the Agent to create a promotional artwork task."
    )
    .frame(width: 600, height: 400)
}