import SwiftUI
import KernelLumi
import LumiUI

/// Database Sidebar 列表为空时的占位视图。
///
/// 样式与 `ConversationListPlugin.ListEmptyView` 保持一致：
/// 系统图标 + caption 文本，纵向居中显示。
struct SidebarEmptyView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    /// 资源为空时显示的系统图标。
    let systemImage: String

    /// 资源为空时显示的提示文本。
    let title: String

    /// 可选的辅助说明文本。
    let description: String?

    // MARK: - Initialization

    init(systemImage: String, title: String, description: String? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.appTitle)
                .foregroundColor(theme.textTertiary)

            Text(title)
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)

            if let description {
                Text(description)
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview("No tables") {
    SidebarEmptyView(
        systemImage: "tablecells",
        title: LumiPluginLocalization.string("No tables", bundle: .module),
        description: "Click Reload to refresh the table list."
    )
    .frame(width: 260, height: 200)
}

#Preview("No keys") {
    SidebarEmptyView(
        systemImage: "key",
        title: LumiPluginLocalization.string("No keys", bundle: .module)
    )
    .frame(width: 260, height: 200)
}
#endif
