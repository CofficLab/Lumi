import SwiftUI

/// 面板区域空状态视图（无内容面板且无底部面板时显示）
struct PanelEmptyStateView: View {
    @EnvironmentObject private var layoutVM: WindowLayoutVM

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.bottomthird.inset.filled")
                .font(.appLargeTitle)
                .foregroundColor(.secondary)

            Text("面板区域为空")
                .font(.appBodyEmphasized)
                .foregroundColor(.secondary)

            Text("打开终端或输出面板以查看内容")
                .font(.appCaption)
                .foregroundColor(Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
