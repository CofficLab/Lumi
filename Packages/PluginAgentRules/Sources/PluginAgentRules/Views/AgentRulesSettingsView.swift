import AppKit
import Combine
import Foundation
import LumiUI
import ProviderProject
import SwiftUI

/// 观察项目服务，避免在 SwiftUI 中直接持有 `any ProjectProviding`。
@MainActor
private final class AgentRulesProjectObserver: ObservableObject {
    @Published private(set) var projects: [ProjectInfo] = []

    private var cancellable: AnyCancellable?

    init(projectProvider: (any ProjectProviding)?) {
        guard let projectProvider else { return }

        projects = projectProvider.projects
        cancellable = projectProvider.objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
            .sink { [weak self] _ in
                guard let self else { return }
                self.projects = projectProvider.projects
            }
    }
}

/// Agent Rules 设置视图。
///
/// - 左侧为项目列表。
/// - 右侧为所选项目 `.agent/rules` 目录中的规则列表。
@MainActor
public struct AgentRulesSettingsView: View {
    @LumiTheme private var theme

    @StateObject private var projectObserver: AgentRulesProjectObserver
    @State private var selectedProjectPath: String?
    @State private var rules: [AgentRuleMetadata] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(projectProvider: (any ProjectProviding)? = nil) {
        _projectObserver = StateObject(
            wrappedValue: AgentRulesProjectObserver(projectProvider: projectProvider)
        )
    }

    private var projects: [ProjectInfo] {
        projectObserver.projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedProject: ProjectInfo? {
        guard let selectedProjectPath else { return nil }
        return projects.first { $0.path == selectedProjectPath }
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Agent Rules", bundle: .module),
            subtitle: LumiPluginLocalization.string(
                "View and manage rule documents in .agent/rules directory",
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
        .task { await reload() }
        .onAppear { seedSelectionIfNeeded() }
        .onChange(of: projects.map(\.path)) { _, _ in
            syncSelectionAfterProjectChange()
        }
        .onChange(of: selectedProjectPath) { _, _ in
            Task { await reload() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            if let selectedProject {
                Label(selectedProject.name, systemImage: "folder")
            }
            Spacer()
            AppButton(LumiPluginLocalization.string("Refresh", bundle: .module), systemImage: "arrow.clockwise", size: .small) {
                Task { await reload() }
            }
            AppButton(LumiPluginLocalization.string("Open Rules Directory", bundle: .module), systemImage: "folder", size: .small) {
                openRulesDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Project List

    private var sidebar: some View {
        VStack(spacing: 0) {
            if projects.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: "No projects yet"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(projects, id: \.path) { project in
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
        let isSelected = selectedProjectPath == project.path

        return AppListRow(isSelected: isSelected, action: {
            selectedProjectPath = project.path
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
                Label("\(rules.count) rules", systemImage: "doc.text")
                Spacer()
            }
            .font(.appCaption)
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.background)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                AppEmptyState(icon: "exclamationmark.triangle", title: error)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedProject == nil {
                AppEmptyState(icon: "folder", title: "Select a project")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rules.isEmpty {
                AppEmptyState(icon: "doc.text", title: "No rules yet")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(rules) { rule in
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

    // MARK: - Data

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let projectPath = selectedProjectPath else {
            rules = []
            return
        }
        let rulesDirectory = getRulesDirectory(for: projectPath)

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: rulesDirectory.path()) {
            rules = []
            return
        }

        do {
            rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)
        } catch {
            errorMessage = error.localizedDescription
            rules = []
        }
    }

    private func seedSelectionIfNeeded() {
        guard selectedProjectPath == nil else { return }
        selectedProjectPath = projectObserver.projects.first?.path
    }

    private func syncSelectionAfterProjectChange() {
        if let selectedProjectPath, projects.contains(where: { $0.path == selectedProjectPath }) {
            return
        }
        selectedProjectPath = projects.first?.path
    }

    private func getRulesDirectory(for projectPath: String) -> URL {
        if projectPath.isEmpty {
            // Global rules directory
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".agent/rules")
        }
        let projectURL = URL(fileURLWithPath: projectPath)
        return projectURL.appendingPathComponent(".agent/rules")
    }

    // MARK: - Actions

    private func openRulesDirectory() {
        guard let projectPath = selectedProjectPath else { return }
        let url = getRulesDirectory(for: projectPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
