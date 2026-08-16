import SwiftUI

/// Rail 顶部（全宽）的空态：插件存储不可用时展示。
struct PromoRailEmptyView: View {
    let message: String

    // MARK: - 初始化

    init(message: String) {
        self.message = message
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
    }
}

// MARK: - 预览

#Preview {
    PromoRailEmptyView(message: "Plugin storage is unavailable.")
        .frame(width: 240, height: 200)
}