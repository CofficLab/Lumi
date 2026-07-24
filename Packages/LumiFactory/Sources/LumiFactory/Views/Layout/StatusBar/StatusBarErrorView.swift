import SwiftUI

/// 状态栏错误视图
///
/// 当 SharedUI 服务不可用时显示错误提示。
struct StatusBarErrorView: View {
    let message: String
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
            Spacer()
            Text("⚠️ Service Error")
                .foregroundColor(.orange)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(isHovered ? Color.red.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help("SharedUI service is not registered. Please ensure SharedUIPlugin is loaded.")
    }
}