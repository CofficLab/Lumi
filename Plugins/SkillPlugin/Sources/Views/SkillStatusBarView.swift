import AppKit
import LumiUI
import LumiCoreKit
import SuperLogKit
import os
import SwiftUI

private enum SkillStatusBarLogging {
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.skill")
    static let verbose = false
}

/// Skill 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的可用 Skill 数量。
/// 点击弹出 Skill 列表面板。
/// 当 Skill 数量为 0 时自动隐藏。
public struct SkillStatusBarView: View, SuperLog {
    private let projectPath: String
    @State private var skills: [SkillMetadata] = []
    @State private var refreshTask: Task<Void, Never>?

    public init(projectPath: String) {
        self.projectPath = projectPath
    }

    public var body: some View {
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
                            .font(.appMicro)
                        Text("\(skills.count)")
                            .font(.appMicroEmphasized)
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
        .onChange(of: projectPath) { _, _ in
            refreshSkills()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSkills()
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    // MARK: - 私有方法

    private func refreshSkills() {
        let projectPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if SkillStatusBarLogging.verbose {
            SkillStatusBarLogging.logger.info("\(Self.t)刷新 Skill 列表，项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
        }
        guard !projectPath.isEmpty else {
            if SkillStatusBarLogging.verbose {
                SkillStatusBarLogging.logger.info("\(Self.t)项目路径为空，清空 Skill 列表")
            }
            refreshTask?.cancel()
            refreshTask = nil
            skills = []
            return
        }

        refreshTask?.cancel()
        refreshTask = Task.detached(priority: .utility) {
            let loaded = await SkillService.shared.listSkills(projectPath: projectPath)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                skills = loaded
            }
            if SkillStatusBarLogging.verbose {
                SkillStatusBarLogging.logger.info("\(Self.t)刷新完成，找到 \(loaded.count) 个 Skill")
            }
        }
    }
}

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

// MARK: - 预览

#Preview("SkillStatusBarView") {
    SkillStatusBarView(projectPath: "/tmp/lumi")
}

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
