import SwiftUI
import LumiUI
import LumiKernel

// MARK: - Skill 列表弹出面板

/// Skill 列表面板
///
/// 点击状态栏 Skill 图标后弹出，展示当前项目所有可用 Skill 的详情。
public struct SkillListPopover: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    
    public let skills: [SkillMetadata]
    
    public var body: some View {
        StatusBarPopoverScaffold(
            title: LumiPluginLocalization.string("^[\(skills.count) Available Skill](inflect: true)", bundle: .module),
            systemImage: "sparkles"
        ) {
            HStack {
                Spacer()
                Text(LumiPluginLocalization.string("Skills are loaded from .agent/skills/", bundle: .module))
                    .font(.appMicro)
                    .foregroundColor(theme.textTertiary)
            }
        } content: {
            // Skill 列表
            ForEach(skills) { skill in
                SkillRow(skill: skill)
            }
        }
    }
}

// MARK: - Preview

#Preview("SkillListPopover") {
    SkillListPopover(skills: [
        SkillMetadata(
            id: "swiftui-expert",
            name: "swiftui-expert",
            title: "SwiftUI Expert",
            description: LumiPluginLocalization.string("Apple HIG compliant SwiftUI code generation with modern patterns", bundle: .module),
            triggers: ["swift", "swiftui"],
            version: "1.0.0",
            contentPath: "",
            modifiedAt: Date()
        ),
        SkillMetadata(
            id: "git-workflow",
            name: "git-workflow",
            title: "Git Workflow",
            description: LumiPluginLocalization.string("Strict git commit conventions and branch management", bundle: .module),
            triggers: ["git"],
            version: "2.1.0",
            contentPath: "",
            modifiedAt: Date()
        )
    ])
    .padding()
    .frame(width: 360)
}
