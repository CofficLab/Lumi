import LumiUI
import SwiftUI

/// 规则列表行：复刻 SkillRowView 的 LumiUI 样式。
struct AgentRuleRowView: View {
    let rule: AgentRuleMetadata
    let onTap: () -> Void

    var body: some View {
        AppListRow {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        if !rule.description.isEmpty {
                            Text(rule.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Text(rule.formattedFileSize)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
