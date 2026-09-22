import AppKit
import Combine
import Foundation
import LumiUI
import ProviderProject
import ProviderSkill
import SwiftUI

/// Skill 设置视图。
///
/// - 左侧为项目列表。
/// - 右侧为所选项目的技能列表，分两组：
///   - 项目技能：`.agent/skills` 目录中的技能（项目层）；
///   - 通用技能：插件贡献 + 内置技能（`SkillProviding` 聚合底座）。
///
/// 只依赖 `SkillSettingsViewModel`；项目 / 底座变化由 `SkillSettingsObserver`
/// 直接写入 ViewModel，View 不再持有 Observer 或业务状态。
@MainActor
struct SkillSettingsView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: SkillSettingsViewModel

    init(viewModel: SkillSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Skills", bundle: .module),
            subtitle: LumiPluginLocalization.string(
                "View project skills and contributed skills",
                bundle: .module
            ),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(spacing: 12) {
                header

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task { await viewModel.reload() }
        .onAppear { viewModel.seedSelectionIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            if let selectedProject = viewModel.selectedProject {
                Label(selectedProject.name, systemImage: "folder")
            }
            Spacer()
            AppButton(LumiPluginLocalization.string("Refresh", bundle: .module), systemImage: "arrow.clockwise", size: .small) {
                viewModel.refresh()
            }
            AppButton(LumiPluginLocalization.string("Open Skills Directory", bundle: .module), systemImage: "folder", size: .small) {
                viewModel.openSkillsDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Project List

    private var sidebar: some View {
        VStack(spacing: 0) {
            if viewModel.projectsSorted.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: LumiPluginLocalization.string("No projects yet", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.projectsSorted, id: \.path) { project in
                            projectRow(project)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func projectRow(_ project: ProjectInfo) -> some View {
        let isSelected = viewModel.selectedProjectPath == project.path

        return AppListRow(isSelected: isSelected, action: {
            viewModel.selectProject(path: project.path)
        }) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Skill List

    private var detailPane: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(viewModel.availableSkillCount) skills", systemImage: "sparkles")
                Spacer()
            }
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.background)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                AppEmptyState(icon: "exclamationmark.triangle", title: error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.selectedProject == nil {
                AppEmptyState(icon: "folder", title: LumiPluginLocalization.string("Select a project", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.availableSkillCount == 0 {
                AppEmptyState(icon: "sparkles", title: LumiPluginLocalization.string("No Skills", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        skillSection(
                            title: LumiPluginLocalization.string(
                                "Project Skills",
                                bundle: .module
                            ),
                            subtitle: LumiPluginLocalization.string(
                                "From .agent/skills directory",
                                bundle: .module
                            ),
                            count: viewModel.projectSkills.count,
                            skills: viewModel.projectSkills,
                            emptyTitle: LumiPluginLocalization.string("No project skills yet", bundle: .module)
                        )

                        skillSection(
                            title: LumiPluginLocalization.string(
                                "Built-in & Plugin Skills",
                                bundle: .module
                            ),
                            subtitle: LumiPluginLocalization.string(
                                "Contributed by the app and plugins",
                                bundle: .module
                            ),
                            count: viewModel.baseSkills.count,
                            skills: viewModel.baseSkills,
                            emptyTitle: LumiPluginLocalization.string("No shared skills", bundle: .module)
                        )
                    }
                    .padding(12)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func skillSection(
        title: String,
        subtitle: String,
        count: Int,
        skills: [SkillMetadata],
        emptyTitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(count) \(title)")
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if skills.isEmpty {
                Text(emptyTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(skills) { skill in
                        SkillRowView(skill: skill)
                    }
                }
            }
        }
    }
}
