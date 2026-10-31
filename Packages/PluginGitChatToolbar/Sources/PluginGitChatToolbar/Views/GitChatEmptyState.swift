import LumiUI
import SwiftUI

/// 弹层空状态：图标 + 标题 + 描述。
struct GitChatEmptyState: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        AppEmptyState(icon: icon, title: title, description: description)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
