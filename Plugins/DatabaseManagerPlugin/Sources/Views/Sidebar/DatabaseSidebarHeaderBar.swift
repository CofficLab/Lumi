import SwiftUI
import LumiKernel
import LumiUI

/// Database Sidebar 顶部标题栏。
///
/// 左侧显示当前连接类型对应的图标和标题（Tables / Keys），
/// 右侧放置 Load 按钮，点击时根据连接类型重新加载数据。
///
/// 样式与 `ConversationListPlugin.ListView` 的 `headerBar` 保持一致：
/// secondary 图标 + caption 标题 + secondary 0.06 背景，
/// `padding(.horizontal, 10)` / `padding(.vertical, 6)`。
struct DatabaseSidebarHeaderBar: View {

    // MARK: - Properties

    /// 显示的标题（"Tables" / "Keys"）。
    let title: String

    /// 标题左侧的系统图标。
    let systemImage: String

    /// 点击 Load 按钮触发的回调。
    let onLoad: () -> Void

    // MARK: - Initialization

    init(title: String, systemImage: String, onLoad: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.onLoad = onLoad
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Button(action: onLoad) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(LumiPluginLocalization.string("Reload", bundle: .module))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06))
    }
}

#if DEBUG
#Preview("Tables") {
    DatabaseSidebarHeaderBar(title: "Tables", systemImage: "tablecells", onLoad: {})
        .frame(width: 260)
}

#Preview("Keys") {
    DatabaseSidebarHeaderBar(title: "Keys", systemImage: "key", onLoad: {})
        .frame(width: 260)
}
#endif