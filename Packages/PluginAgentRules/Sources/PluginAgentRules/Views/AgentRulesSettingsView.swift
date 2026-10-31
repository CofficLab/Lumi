import AppKit
import Combine
import Foundation
import LumiUI
import ProviderProject
import SwiftUI

/// Agent Rules 设置视图。
///
/// - 左侧为项目列表。
/// - 右侧为所选项目 `.lumi/rules` 目录中的规则列表。
///
/// 只依赖 `AgentRulesViewModel`；项目变化由 `AgentRulesProjectObserver`
/// 直接写入 ViewModel，View 不再持有 Observer 或业务状态。
@MainActor
struct AgentRulesSettingsView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: AgentRulesViewModel

    init(viewModel: AgentRulesViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Agent Rules"),
            subtitle: pluginLocalization.string("View and manage rule documents in .lumi/rules directory"),
            showHeader: false,
            scrollsContent: false
        ) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    // 主体内容贴边后，用一条顶部分隔线把头部行与主从容器分开。
                    AppDivider()

                    HStack(spacing: 0) {
                        sidebar
                            .frame(width: 300)
                            .frame(maxHeight: .infinity)

                        AppDivider(.vertical)

                        detailPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(maxHeight: .infinity)
                }
                // 共享 scaffold 给内容留了左右 24，这里把整列加宽 48 并左移 24，
                // 使主从容器正好贴到窗口左右边缘；标题行再自行补回 24 留白。
                .frame(width: proxy.size.width + 48, alignment: .topLeading)
                .offset(x: -24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
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
            AppButton(pluginLocalization.string("Refresh"), systemImage: "arrow.clockwise", size: .small) {
                viewModel.refresh()
            }
            AppButton(pluginLocalization.string("Open Rules Directory"), systemImage: "folder", size: .small) {
                viewModel.openRulesDirectory()
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
                    title: pluginLocalization.string("No projects yet")
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

    // MARK: - Rule List

    private var detailPane: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(viewModel.rules.count) rules", systemImage: "doc.text")
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
                AppEmptyState(icon: "folder", title: pluginLocalization.string("Select a project"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.rules.isEmpty {
                AppEmptyState(icon: "doc.text", title: pluginLocalization.string("No rules yet"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.rules) { rule in
                            ruleRow(rule)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private func ruleRow(_ rule: AgentRuleMetadata) -> some View {
        AppListRow(isSelected: false, action: {}) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(rule.filename)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
        }
    }
}
