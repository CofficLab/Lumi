import AppKit
import LumiUI
import KernelLumi
import SuperLogKit
import SwiftUI

/// Skill 聊天工具栏视图
///
/// 在 Chat 工具栏显示当前项目的可用 Skill 数量。
/// 点击弹出 Skill 列表面板。
/// 当 Skill 数量为 0 时自动隐藏。
public struct SkillChatToolbarView: View, SuperLog {
    public nonisolated static let emoji = "📊"

    private let project: any ProjectProviding
    @State private var skills: [SkillMetadata] = []
    @State private var refreshTask: Task<Void, Never>?

    public init(project: any ProjectProviding) {
        self.project = project
    }

    private var projectPath: String {
        project.currentProject?.path ?? ""
    }

    public var body: some View {
        Group {
            // 无 Skill 时不显示
            if !skills.isEmpty {
                StatusBarHoverContainer(
                    detailView: SkillListPopover(skills: skills),
                    popoverWidth: 360,
                    id: "skill-toolbar"
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
            refreshSkills(reason: "视图出现")
        }
        .onChange(of: projectPath) { _, _ in
            refreshSkills(reason: "项目路径变更")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSkills(reason: "应用激活")
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    // MARK: - 私有方法

    private func refreshSkills(reason: String) {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if SkillPlugin.verbose {
            SkillPlugin.logger.info("\(Self.t)刷新 Skill 列表，原因：\(reason)，项目路径：\(path.isEmpty ? "<未选择>" : path)")
        }
        guard !path.isEmpty else {
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
            let loaded = await SkillService.shared.listSkills(projectPath: path)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                skills = loaded
            }
            if SkillPlugin.verbose {
                SkillPlugin.logger.info("\(SkillChatToolbarView.t)刷新完成，找到 \(loaded.count) 个 Skill")
            }
        }
    }
}
