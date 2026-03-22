import SwiftUI

/// 将 `PermissionRequestView` 叠在根内容之上（`content` 在插件系统里通常为占位，仅占满布局）。
struct ToolPermissionRootOverlay<Content: View>: View {
    let content: Content

    var body: some View {
        ZStack {
            content
            PermissionRequestView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
