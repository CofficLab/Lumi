import LumiUI
import ProviderSkill
import SwiftUI

/// 技能列表行：复刻 PluginProjects.RowView 的 LumiUI 样式。
struct SkillRowView: View {
    let skill: SkillMetadata

    var body: some View {
        AppListRow {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
    }
}
