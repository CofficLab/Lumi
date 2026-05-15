import MagicKit
import os
import SkillKit
import SwiftUI

/// Skill 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的可用 Skill 数量。
/// 点击弹出 Skill 列表面板。
/// 当 Skill 数量为 0 时自动隐藏。
struct SkillStatusBarView: View, SuperLog {
    nonisolated static let emoji = "✨"
    nonisolated static var verbose: Bool { SkillPlugin.verbose }
    nonisolated static var logger: Logger { SkillPlugin.logger }

    @EnvironmentObject private var projectVM: ProjectVM
    @State private var skills: [SkillMetadata] = []

    var body: some View {
        Group {
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
                        Text("\(skills.count)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        // 与 GitPluginStatusBarView 保持一致的刷新时机
        .onAppear {
            refreshSkills()
        }
        .onChange(of: projectVM.currentProjectPath) { _, _ in
            refreshSkills()
        }
        .onApplicationDidBecomeActive {
            refreshSkills()
        }
    }

    // MARK: - 私有方法

    private func refreshSkills() {
        let projectPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.verbose {
            Self.logger.info("\(self.t)刷新 Skill 列表，项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
        }
        guard !projectPath.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(self.t)项目路径为空，清空 Skill 列表")
            }
            skills = []
            return
        }
        Task {
            let loaded = await SkillService.shared.listSkills(projectPath: projectPath)
            await MainActor.run {
                skills = loaded
            }
            if Self.verbose {
                Self.logger.info("\(SkillStatusBarView.t)刷新完成，找到 \(loaded.count) 个 Skill")
                for s in loaded {
                    Self.logger.info("\(SkillStatusBarView.t)Skill：\(s.name) - \(s.title)")
                }
            }
        }
    }
}

// MARK: - Skill 列表弹出面板

/// Skill 列表面板
///
/// 点击状态栏 Skill 图标后弹出，展示当前项目所有可用 Skill 的详情。
struct SkillListPopover: View {
    let skills: [SkillMetadata]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "7C6FFF"))

                Text(String(localized: "^[\(skills.count) Available Skill](inflect: true)", table: "Skill"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                Text(String(localized: "Skills are loaded from .agent/skills/", table: "Skill"))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "98989E"))
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
        HStack(alignment: .top, spacing: 16) {
            // 图标
            Image(systemName: "sparkle")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "7C6FFF"))
                .padding(.top, 2)

            // 信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(skill.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                    Text("v\(skill.version)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "98989E"))
                }

                Text(skill.description)
                    .font(.system(size: 11))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
