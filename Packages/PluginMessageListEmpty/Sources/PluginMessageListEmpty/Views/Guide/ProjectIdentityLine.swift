import LumiUI
import SwiftUI

/// 项目身份行：路径 + 技术栈。
///
/// ## 它占的是副标题的槽位
///
/// 空态原本有一行「选个例子，或在下方输入你的问题」。有项目时那行信息量太低，
/// 换成项目身份更有用——用户需要先确认「我在哪个项目里」，才能决定要不要在这里提问。
///
/// ## 为什么只显示路径尾巴
///
/// 全路径太长（`/Users/colorfy/Code/CofficLab/Lumi`）；折叠家目录后的
/// `~/Code/CofficLab/Lumi` 既短又能消歧——本机同名项目很常见。
struct ProjectIdentityLine: View {
    @LumiTheme private var theme
    let identity: ProjectContextIdentity

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)

            Text(identity.displayPath)
                .font(.system(size: 12.5))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.head)

            if let type = identity.typeLabels.first {
                Text("·")
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.textSecondary.opacity(0.7))
                Text(type)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(MessageListEmptyAccessibility.projectIdentityLineID)
    }
}
