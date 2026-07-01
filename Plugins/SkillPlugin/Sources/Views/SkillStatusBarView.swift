import AppKit
import LumiUI
import LumiCoreKit
import SuperLogKit
import SwiftUI

/// Skill 状态栏视图
///
/// 在 Agent 模式底部状态栏显示当前项目的可用 Skill 数量。
/// 点击弹出 Skill 列表面板。
/// 当 Skill 数量为 0 时自动隐藏。
public struct SkillStatusBarView: View, SuperLog {
    public nonisolated static let emoji = "📊"

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
        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)刷新 Skill 列表，项目路径：\(projectPath.isEmpty ? "<未选择>" : projectPath)")
        }
        guard !projectPath.isEmpty else {
            if SkillPlugin.verbose {
                SkillPlugin.logger.info("\(Self.t)项目路径为空，清空 Skill 列表")
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
            if SkillPlugin.verbose {
                SkillPlugin.logger.info("\(SkillStatusBarView.t)刷新完成，找到 \(loaded.count) 个 Skill")
            }
        }
    }
}

// MARK: - Preview

#Preview("SkillStatusBarView") {
    SkillStatusBarView(projectPath: "/tmp/lumi")
}
