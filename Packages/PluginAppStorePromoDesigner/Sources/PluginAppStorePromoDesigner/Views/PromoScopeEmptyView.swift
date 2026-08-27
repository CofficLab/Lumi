import SwiftUI

/// 单个 scope 分组内（缩进更浅）的空态提示文字。
struct PromoScopeEmptyView: View {
    let message: String

    // MARK: - 初始化

    init(message: String) {
        self.message = message
    }

    // MARK: - Body

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 18)
            .padding(.vertical, 6)
    }
}

// MARK: - 预览

#Preview {
    VStack(alignment: .leading) {
        PromoScopeEmptyView(message: PromoLocalization.string("Open a project to enable project-local storage."))
        PromoScopeEmptyView(message: PromoLocalization.string("Ask the Agent to create a promotional artwork task."))
    }
    .frame(width: 280)
}