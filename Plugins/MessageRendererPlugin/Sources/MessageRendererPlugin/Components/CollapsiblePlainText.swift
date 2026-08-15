import KernelLumi
import KernelLumi
import LumiUI
import SwiftUI

struct CollapsiblePlainText: View {
    @LumiTheme private var theme

    let text: String
    @State private var isCollapsed = true

    private let collapseLineLimit = 40
    /// 超过该行数下限的文本才需要切分统计行数:40 行文本至少 40 个字符,
    /// 短于此的一定不可折叠,直接跳过 O(n) 的整串切分与拼接。
    private static let minimumCollapsibleLength = 40

    var body: some View {
        // 长度守卫:绝大多数消息远短于折叠阈值,不必每次 body 求值
        // (含滚动重物化)都做整串 components + joined。
        let lines = text.count >= Self.minimumCollapsibleLength
            ? text.components(separatedBy: .newlines)
            : []
        let shouldCollapse = lines.count > collapseLineLimit
        let rendered = shouldCollapse && isCollapsed
            ? lines.prefix(collapseLineLimit).joined(separator: "\n") + "\n..."
            : text

        VStack(alignment: .leading, spacing: 6) {
            Text(rendered)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .lineSpacing(3)
                .textSelection(.enabled)

            if shouldCollapse {
                Button(isCollapsed ? LumiPluginLocalization.string("Show more", bundle: .module) : LumiPluginLocalization.string("Show less", bundle: .module)) {
                    isCollapsed.toggle()
                }
                .buttonStyle(.plain)
                .font(.appCaption)
                .foregroundColor(theme.primary)
            }
        }
    }
}
