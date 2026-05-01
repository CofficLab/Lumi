import MagicKit
import SwiftUI

/// Skill 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的可用 Skill 数量。
/// 点击弹出 Skill 列表面板。
/// 当 Skill 数量为 0 时自动隐藏。
struct SkillStatusBarView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @State private var skills: [SkillMetadata] = []

    var body: some View {
        // 无 Skill 时不显示
        if !skills.isEmpty {
            StatusBarHoverContainer(
                detailView: SkillListPopover(skills: skills),
                popoverWidth: 360,
                id: "skill-status"
            ) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("^[\(skills.count) Skill](inflect: true)")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .task {
                await loadSkills()
            }
            .onChange(of: projectVM.currentProjectPath) { _, _ in
                Task { await loadSkills() }
            }
        }
    }

    // MARK: - 私有方法

    private func loadSkills() async {
        let projectPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else {
            skills = []
            return
        }
        skills = await SkillService.shared.listSkills(projectPath: projectPath)
    }
}

// MARK: - Skill 列表弹出面板

/// Skill 列表面板
///
/// 点击状态栏 Skill 图标后弹出，展示当前项目所有可用 Skill 的详情。
struct SkillListPopover: View {
    let skills: [SkillMetadata]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text("^[\(skills.count) Available Skill](inflect: true)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Text(String(localized: "Skills are loaded from .agent/skills/", table: "Skill"))
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }

            Divider()

            // Skill 列表
            ForEach(skills) { skill in
                SkillRow(skill: skill)
            }
        }
    }
}

// MARK: - Skill 行视图

/// 单个 Skill 的展示行
struct SkillRow: View {
    let skill: SkillMetadata

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // 图标
            Image(systemName: "sparkle")
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.primary)
                .padding(.top, 2)

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text("v\(skill.version)")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }

                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览

#Preview("SkillStatusBarView") {
    SkillStatusBarView()
        .environmentObject(ProjectVM(
            contextService: ContextService(),
            llmService: LLMService(registry: LLMProviderRegistry())
        ))
}

#Preview("SkillListPopover") {
    SkillListPopover(skills: [
        SkillMetadata(
            id: "swiftui-expert",
            name: "swiftui-expert",
            title: "SwiftUI Expert",
            description: "Apple HIG compliant SwiftUI code generation with modern patterns",
            triggers: ["swift", "swiftui"],
            version: "1.0.0",
            contentPath: "",
            modifiedAt: Date()
        ),
        SkillMetadata(
            id: "git-workflow",
            name: "git-workflow",
            title: "Git Workflow",
            description: "Strict git commit conventions and branch management",
            triggers: ["git"],
            version: "2.1.0",
            contentPath: "",
            modifiedAt: Date()
        )
    ])
    .padding()
    .frame(width: 360)
}
