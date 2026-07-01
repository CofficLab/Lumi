import SwiftUI
import LumiUI
import LumiCoreKit

// MARK: - Skill 行视图

/// 单个 Skill 的展示行
public struct SkillRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    
    public let skill: SkillMetadata
    
    public var body: some View {
        AppListRow {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkle")
                    .font(.appCaption)
                    .foregroundColor(theme.primary)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(skill.title)
                            .font(.appCallout)
                            .foregroundColor(theme.textPrimary)
                        
                        Text("v\(skill.version)")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }
                    
                    Text(skill.description)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
