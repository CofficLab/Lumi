import SwiftUI
import LumiCoreKit
import LumiUI
import UniformTypeIdentifiers

/// 未选择项目时的全屏引导遮罩
/// 提供最近项目快速选择和添加新项目入口
public struct NoProjectOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var recentProjectsVM: AppProjectsVM

    @State private var isFileImporterPresented = false
    @State private var isFolderDropTargeted = false

    private let store = ProjectsStore()

    public var body: some View {
        ZStack {
            // 半透明背景遮罩
            backgroundOverlay

            // 居中内容卡片
            cardContent

            if isFolderDropTargeted {
                folderDropHintOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.12), value: isFolderDropTargeted)
        .onDrop(
            of: [UTType.fileURL],
            delegate: NoProjectFolderDropDelegate(
                isDropTargeted: $isFolderDropTargeted,
                onPerform: acceptFolderDrop
            )
        )
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Drop Hint

    private var folderDropHintOverlay: some View {
        ZStack {
            (colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.45))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6]),
                    antialiased: true
                )
                .foregroundStyle(Color(hex: "7C6FFF").opacity(0.85))
                .padding(20)

            VStack(spacing: 10) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 28, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(hex: "7C6FFF"))

                Text(String(localized: "Release to add project", bundle: .module))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - Background Overlay

    private var backgroundOverlay: some View {
        colorScheme == .dark
            ? Color.black.opacity(0.6)
            : Color.white.opacity(0.7)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 24) {
            // 图标与标题
            headerSection

            // 最近项目列表（如果有）
            if !recentProjectsVM.recentProjects.isEmpty {
                recentProjectsSection
            }

            // 操作按钮
            actionButtons
        }
        .padding(32)
        .frame(maxWidth: 380)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? .white.opacity(0.08)
                        : .black.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08),
            radius: 30,
            y: 10
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "7C6FFF").opacity(0.15),
                                Color(hex: "7C6FFF").opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "7C6FFF"), Color(hex: "5B8DEF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(String(localized: "No Project Selected", bundle: .module))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(String(localized: "Select a project to get started", bundle: .module))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Projects Section

    private var recentProjectsSection: some View {
        VStack(spacing: 4) {
            Text(String(localized: "Projects", bundle: .module))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 最近项目列表（最多显示 5 个）
            let displayProjects = Array(recentProjectsVM.recentProjects.prefix(5))

            ForEach(displayProjects) { project in
                recentProjectRow(project)
            }
        }
    }

    private func recentProjectRow(_ project: Project) -> some View {
        Button {
            selectProject(project)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(project.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                        ? .white.opacity(0.05)
                        : .black.opacity(0.03)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            // 添加新项目按钮（主操作）
            Button {
                isFileImporterPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text(String(localized: "Add New Project", bundle: .module))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "7C6FFF"), Color(hex: "5B8DEF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            // 提示文字
            Text(String(localized: "Or drag a folder here", bundle: .module))
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Actions

    private func selectProject(_ project: Project) {
        recentProjectsVM.addProject(project)
        projectVM.switchProject(to: project, reason: "noProjectOverlaySelect")
    }

    private func addProjectAndSwitch(to url: URL) {
        let standardizedURL = url.standardizedFileURL
        let project = Project(
            name: standardizedURL.lastPathComponent,
            path: standardizedURL.path,
            lastUsed: Date()
        )
        store.addProject(name: project.name, path: project.path)
        recentProjectsVM.addProject(project)
        projectVM.switchProject(to: project, reason: "noProjectOverlayAddProject")
    }

    // MARK: - Folder Drop

    private func acceptFolderDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { item, _ in
                guard let url = item else { return }
                Task { @MainActor in
                    importDroppedFolder(url)
                }
            }
            return true
        }
        return false
    }

    private func importDroppedFolder(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else { return }

        let needsScope = url.startAccessingSecurityScopedResource()
        addProjectAndSwitch(to: url)
        if needsScope {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let folderURL = urls.first else { return }
            guard folderURL.startAccessingSecurityScopedResource() else { return }
            addProjectAndSwitch(to: folderURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                folderURL.stopAccessingSecurityScopedResource()
            }
        case let .failure(error):
            if ProjectsPlugin.verbose {
                ProjectsPlugin.logger.error("File import error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Drop Delegate

private struct NoProjectFolderDropDelegate: DropDelegate {
    @Binding var isDropTargeted: Bool
    public var onPerform: ([NSItemProvider]) -> Bool

    public func validateDrop(info: DropInfo) -> Bool {
        !info.itemProviders(for: [UTType.fileURL]).isEmpty
    }

    public func dropEntered(info: DropInfo) {
        isDropTargeted = validateDrop(info: info)
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        isDropTargeted = validateDrop(info: info)
        return validateDrop(info: info) ? DropProposal(operation: .copy) : DropProposal(operation: .forbidden)
    }

    public func dropExited(info: DropInfo) {
        isDropTargeted = false
    }

    public func performDrop(info: DropInfo) -> Bool {
        isDropTargeted = false
        let providers = info.itemProviders(for: [UTType.fileURL])
        guard !providers.isEmpty else { return false }
        return onPerform(providers)
    }
}

// MARK: - Preview

#Preview("No Project Overlay") {
    ZStack {
        Color.gray.opacity(0.3)
        NoProjectOverlay()
    }
    .frame(width: 800, height: 600)
    .inRootView()
}
