import SwiftUI
import UniformTypeIdentifiers

// MARK: - No Project Overlay

/// 未选择项目时的全屏引导遮罩
/// 提供最近项目快速选择和添加新项目入口
struct NoProjectOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    let recentProjects: [Project]
    @Binding var isFileImporterPresented: Bool
    let onSelectProject: (Project) -> Void
    let onAddProject: (URL) -> Void

    var body: some View {
        ZStack {
            // 半透明背景遮罩
            backgroundOverlay

            // 居中内容卡片
            cardContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
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
            if !recentProjects.isEmpty {
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
                                Color(hex: "7C6FFF").opacity(0.05)
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

            Text(String(localized: "No Project Selected", table: "RecentProjects"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(String(localized: "Select a project to get started", table: "RecentProjects"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Recent Projects Section

    private var recentProjectsSection: some View {
        VStack(spacing: 4) {
            Text(String(localized: "Recent Projects", table: "RecentProjects"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 最近项目列表（最多显示 5 个）
            let displayProjects = Array(recentProjects.prefix(5))

            ForEach(displayProjects) { project in
                recentProjectRow(project)
            }
        }
    }

    private func recentProjectRow(_ project: Project) -> some View {
        Button {
            onSelectProject(project)
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
                    Text(String(localized: "Add New Project", table: "RecentProjects"))
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
            Text(String(localized: "Or drag a folder into the window", table: "RecentProjects"))
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else { return }
            guard folderURL.startAccessingSecurityScopedResource() else { return }
            onAddProject(folderURL.standardizedFileURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                folderURL.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            RecentProjectsPlugin.logger.error("File import error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview("No Project Overlay - Empty") {
    ZStack {
        Color.gray.opacity(0.3)
        NoProjectOverlay(
            recentProjects: [],
            isFileImporterPresented: .constant(false),
            onSelectProject: { _ in },
            onAddProject: { _ in }
        )
    }
    .frame(width: 800, height: 600)
    .inRootView()
}

#Preview("No Project Overlay - With Recent") {
    ZStack {
        Color.gray.opacity(0.3)
        NoProjectOverlay(
            recentProjects: [
                Project(name: "Lumi", path: "/Users/dev/Projects/Lumi", lastUsed: Date()),
                Project(name: "MagicKit", path: "/Users/dev/Projects/MagicKit", lastUsed: Date().addingTimeInterval(-3600)),
            ],
            isFileImporterPresented: .constant(false),
            onSelectProject: { _ in },
            onAddProject: { _ in }
        )
    }
    .frame(width: 800, height: 600)
    .inRootView()
}
