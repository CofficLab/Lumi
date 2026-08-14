import SwiftUI

/// 简历面板空态：未选中简历时提示用户通过 Agent 创建。
struct ResumeEmptyStateView: View {
    let message: String

    init(message: String) {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.plus")
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
    ResumeEmptyStateView(message: "Ask the Agent to create a resume.")
        .frame(width: 600, height: 400)
}
