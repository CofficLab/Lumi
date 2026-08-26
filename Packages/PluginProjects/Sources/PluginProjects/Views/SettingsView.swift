import AppKit
import Foundation
import LumiUI
import SwiftUI

/// Projects 设置视图。
///
/// - 顶部右上角按钮可打开数据库目录（`store.settingsDirectory`）。
/// - 下方左侧为项目列表，点击某个项目在右侧展示其详情信息。
@MainActor
public struct SettingsView: View {
    @ObservedObject private var viewModel: ProjectsViewModel
    @LumiTheme private var theme

    @State private var selectedProjectPath: String?
    @State private var didSeedSelection = false
    /// 各项目历史打开文件，key 为标准化后的项目路径。
    /// 放在 `@State` 中而不是在 `body` 里同步读取磁盘，避免每次重绘都阻塞 UI。
    @State private var openedFilesByPath: [String: ProjectOpenedFiles] = [:]
    @State private var isLoadingOpenedFiles = true

    public init(viewModel: ProjectsViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    private var projects: [ProjectEntry] {
        viewModel.projects.sorted { $0.lastUsed > $1.lastUsed }
    }

    private var projectPaths: [String] {
        projects.map(\.path)
    }

    private var selectedProject: ProjectEntry? {
        guard let selectedProjectPath else { return nil }
        return projects.first { $0.path == selectedProjectPath }
    }

    public var body: some View {
        AppSettingsContentScaffold(scrollsContent: false, maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 14) {
                header

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)

                    AppDivider(.vertical)

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 560, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            await loadOpenedFiles()
        }
        .onAppear { seedSelectionIfNeeded() }
        .onChange(of: projectPaths) { _, _ in syncSelectionAfterProjectChange() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label(String(format: LumiPluginLocalization.string("%lld projects", bundle: .module), projects.count), systemImage: "folder")
            if let selected = selectedProject {
                Text(LumiPluginLocalization.string("·", bundle: .module))
                Text(selected.name)
            }
            Spacer()
            AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", size: .small) {
                openDataDirectory()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    // MARK: - Sidebar（项目列表）

    private var sidebar: some View {
        VStack(spacing: 0) {
            if projects.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: LumiPluginLocalization.string("No projects yet", bundle: .module)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(projects) { project in
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

    private func projectRow(_ project: ProjectEntry) -> some View {
        let isSelected = selectedProjectPath == project.path
        let isCurrent = viewModel.currentProject?.path == project.path
        return AppListRow(isSelected: isSelected, action: {
            selectedProjectPath = project.path
            didSeedSelection = true
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
                    HStack(spacing: 6) {
                        Text(project.name)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        if isCurrent {
                            Text(LumiPluginLocalization.string("Current", bundle: .module))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
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

    // MARK: - Detail Pane（项目详情）

    @ViewBuilder
    private var detailPane: some View {
        if let project = selectedProject {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AppSettingsSection(title: LumiPluginLocalization.string("Overview", bundle: .module)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(project.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(2)

                            Text(project.path)
                                .font(.callout)
                                .foregroundStyle(theme.textSecondary)
                                .textSelection(.enabled)
                        }
                    }

                    AppSettingsSection(title: LumiPluginLocalization.string("Basic Info", bundle: .module)) {
                        VStack(spacing: 0) {
                            detailRow(title: LumiPluginLocalization.string("Name", bundle: .module), icon: "text.cursor", value: project.name)
                            Divider().padding(.vertical, 8)
                            detailRow(title: LumiPluginLocalization.string("Path", bundle: .module), icon: "folder", value: project.path, monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(title: LumiPluginLocalization.string("Language", bundle: .module), icon: "character.book.closed", value: project.language?.capitalized ?? LumiPluginLocalization.string("Unknown", bundle: .module))
                            Divider().padding(.vertical, 8)
                            detailRow(title: LumiPluginLocalization.string("Last Used", bundle: .module), icon: "calendar", value: formattedDate(project.lastUsed))
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: LumiPluginLocalization.string("Status", bundle: .module),
                                icon: "star",
                                value: viewModel.currentProject?.path == project.path ? LumiPluginLocalization.string("Current Project", bundle: .module) : LumiPluginLocalization.string("Not Selected", bundle: .module)
                            )
                        }
                    }

                    openedFilesSection(for: project)
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "folder",
                title: projects.isEmpty ? LumiPluginLocalization.string("No projects yet", bundle: .module) : LumiPluginLocalization.string("Select a project", bundle: .module)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    @ViewBuilder
    private func openedFilesSection(for project: ProjectEntry) -> some View {
        let key = ProjectsStore.normalizedPath(project.path)
        // 从 @State 缓存读取，避免每次重绘都去磁盘加载。
        let opened = openedFilesByPath[key]
        let urls = opened?.openFileURLs ?? []
        let current = opened?.currentFileURL

        AppSettingsSection(title: LumiPluginLocalization.string("Opened Files", bundle: .module)) {
            if isLoadingOpenedFiles {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LumiPluginLocalization.string("Loading opened files…", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
            } else if urls.isEmpty {
                Text(LumiPluginLocalization.string("No opened files recorded", bundle: .module))
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let current {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.secondary)
                            Text(current.lastPathComponent)
                                .font(.callout)
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(LumiPluginLocalization.string("Active", bundle: .module))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Array(urls.prefix(20).enumerated()), id: \.offset) { _, url in
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                                .foregroundStyle(.secondary)
                            Text(url.lastPathComponent)
                                .font(.callout)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                    if urls.count > 20 {
                        Text(String(format: LumiPluginLocalization.string("+%lld more", bundle: .module), urls.count - 20))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func detailRow(title: String, icon: String, value: String, monospace: Bool = false) -> some View {
        AppSettingRow(title: title, icon: icon) {
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    // MARK: - Selection Sync

    private func seedSelectionIfNeeded() {
        guard !didSeedSelection else { return }
        didSeedSelection = true
        selectedProjectPath = viewModel.currentProject?.path ?? projects.first?.path
    }

    private func syncSelectionAfterProjectChange() {
        if !didSeedSelection {
            seedSelectionIfNeeded()
            return
        }
        guard let selectedProjectPath, projects.contains(where: { $0.path == selectedProjectPath }) else {
            self.selectedProjectPath = projects.first?.path
            return
        }
    }

    // MARK: - Data

    /// 异步加载所有项目的打开文件记录到 `@State` 缓存。
    ///
    /// 使用 `withCheckedContinuation` 让出控制权，让 SwiftUI 先渲染 loading 状态，
    /// 避免在视图出现时阻塞主线程（来自 HTTPExchangeSettingsView 的修复模式）。
    private func loadOpenedFiles() async {
        await withCheckedContinuation { continuation in
            let loaded = viewModel.store.loadOpenedFiles()
            openedFilesByPath = loaded
            isLoadingOpenedFiles = false
            continuation.resume()
        }
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Actions

    private func openDataDirectory() {
        let url = viewModel.store.settingsDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }
}
