import AppKit
import Foundation
import LumiUI
import ProviderSettingView
import SwiftUI

/// Projects 设置视图。
///
/// - 顶部右上角可添加项目。
/// - 下方左侧为项目列表，点击某个项目在右侧展示其详情信息。
@MainActor
public struct SettingsView: View {
    @ObservedObject private var viewModel: ProjectsViewModel
    @LumiTheme private var theme

    @State private var selectedProjectPath: String?
    @State private var didSeedSelection = false
    private let projectDetailSections: [ProjectDetailSectionItem]

    public init(viewModel: ProjectsViewModel, projectDetailSections: [ProjectDetailSectionItem] = []) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.projectDetailSections = projectDetailSections
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
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
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
        .task {
            viewModel.startObservingOpenedFiles()
        }
        .onAppear { seedSelectionIfNeeded() }
        .onChange(of: projectPaths) { _ in syncSelectionAfterProjectChange() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Label(String(format: pluginLocalization.string("%lld projects"), projects.count), systemImage: "folder")
            if let selected = selectedProject {
                Text(pluginLocalization.string("·"))
                Text(selected.name)
            }
            Spacer()
            AppButton(pluginLocalization.string("Add Project"), systemImage: "plus", style: .secondary, size: .small) {
                addProject()
            }
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = pluginLocalization.string("Select a project folder")
        panel.prompt = pluginLocalization.string("Add")

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.addProject(url: url)
        }
    }

    // MARK: - Sidebar（项目列表）

    private var sidebar: some View {
        VStack(spacing: 0) {
            if projects.isEmpty {
                AppEmptyState(
                    icon: "folder",
                    title: pluginLocalization.string("No projects yet")
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
                ProjectStorageIcon(kind: ProjectStorageDetector.kind(for: project.path), size: 13)
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
                            Text(pluginLocalization.string("Current"))
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
                VStack(alignment: .leading, spacing: 18) {
                    AppSettingSection(
                        title: pluginLocalization.string("Overview"),
                        titleAlignment: .leading
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(project.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .foregroundStyle(theme.textSecondary)
                                Text(project.path)
                                    .font(.callout)
                                    .foregroundStyle(theme.textSecondary)
                                    .textSelection(.enabled)
                                Spacer()
                                AppButton(
                                    pluginLocalization.string("Open in Finder"),
                                    systemImage: "folder",
                                    style: .secondary,
                                    size: .small
                                ) {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: project.path))
                                }
                            }
                        }
                    }

                    AppSettingSection(
                        title: pluginLocalization.string("Basic Info"),
                        titleAlignment: .leading
                    ) {
                        VStack(spacing: 0) {
                            detailRow(title: pluginLocalization.string("Name"), icon: "text.cursor", value: project.name)
                            Divider().padding(.vertical, 8)
                            detailRow(title: pluginLocalization.string("Path"), icon: "folder", value: project.path, monospace: true)
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: pluginLocalization.string("Storage Location"),
                                icon: ProjectStorageDetector.kind(for: project.path).symbolName,
                                value: storageLocationDescription(for: project.path)
                            )
                            Divider().padding(.vertical, 8)
                            detailRow(title: pluginLocalization.string("Language"), icon: "character.book.closed", value: project.language?.capitalized ?? pluginLocalization.string("Unknown"))
                            Divider().padding(.vertical, 8)
                            detailRow(title: pluginLocalization.string("Last Used"), icon: "calendar", value: formattedDate(project.lastUsed))
                            Divider().padding(.vertical, 8)
                            detailRow(
                                title: pluginLocalization.string("Status"),
                                icon: "star",
                                value: viewModel.currentProject?.path == project.path ? pluginLocalization.string("Current Project") : pluginLocalization.string("Not Selected")
                            )
                        }
                    }

                    openedFilesSection(for: project)
                    ForEach(projectDetailSections) { section in
                        section.makeView(project.path)
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        } else {
            AppEmptyState(
                icon: "folder",
                title: projects.isEmpty ? pluginLocalization.string("No projects yet") : pluginLocalization.string("Select a project")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appSurface(style: .panel, cornerRadius: 0)
        }
    }

    @ViewBuilder
    private func openedFilesSection(for project: ProjectEntry) -> some View {
        let key = ProjectsStore.normalizedPath(project.path)
        // 读取 ViewModel 中的缓存：它跟随 Store 变更刷新，避免显示首次进入时的旧快照。
        let opened = viewModel.openedFilesByPath[key]
        let state = Self.openedFilesSectionState(
            isLoading: viewModel.isLoadingOpenedFiles,
            opened: opened
        )

        AppSettingSection(
            title: pluginLocalization.string("Opened Files"),
            titleAlignment: .leading
        ) {
            switch state {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(pluginLocalization.string("Loading opened files…"))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)
                }
            case .empty:
                Text(pluginLocalization.string("No opened files recorded"))
                    .font(.callout)
                    .foregroundStyle(theme.textSecondary)
            case .content(let urls, let current):
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
                            Text(pluginLocalization.string("Active"))
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
                        Text(String(format: pluginLocalization.string("+%lld more"), urls.count - 20))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Opened Files 区域的展示状态。
    ///
    /// Explorer 单击产生的 preview 文件只写入 `currentFileURL`，`openFileURLs`
    /// 仍为空；这种 preview-only 状态必须显示 Active 行，而不是「没有打开文件」。
    enum OpenedFilesSectionState: Equatable {
        case loading
        case empty
        case content(urls: [URL], current: URL?)
    }

    static func openedFilesSectionState(
        isLoading: Bool,
        opened: ProjectOpenedFiles?
    ) -> OpenedFilesSectionState {
        guard !isLoading else { return .loading }
        let urls = opened?.openFileURLs ?? []
        let current = opened?.currentFileURL
        guard urls.isEmpty && current == nil else {
            return .content(urls: urls, current: current)
        }
        return .empty
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

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// 存储位置的可读描述。
    private func storageLocationDescription(for path: String) -> String {
        switch ProjectStorageDetector.kind(for: path) {
        case .internalDisk:
            return pluginLocalization.string("Local Disk")
        case .externalDisk:
            return pluginLocalization.string("External Drive")
        case .networkVolume:
            return pluginLocalization.string("Network Volume")
        case .unavailable:
            return pluginLocalization.string("Device Unavailable")
        }
    }
}
