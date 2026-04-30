import MagicKit
import SwiftUI

// MARK: - 项目下拉菜单

struct ProjectDropdownMenu: View {
    @EnvironmentObject var projectVM: ProjectVM
    @Binding var isPresented: Bool

    let onSelect: (Project) -> Void

    @State private var isFileImporterPresented = false

    private let store = RecentProjectsStore()

    private var recentProjects: [Project] {
        Array(projectVM.recentProjects
            .prefix(10)
            .filter { $0.path != projectVM.currentProjectPath })
    }

    var body: some View {
        VStack(spacing: 6) {
            // 当前项目
            if !projectVM.currentProjectPath.isEmpty {
                DropdownItemView(
                    icon: "hammer.fill",
                    iconColor: .accentColor,
                    title: projectVM.currentProjectName,
                    subtitle: projectVM.currentProjectPath,
                    isCurrent: true,
                    action: {}
                )

                if !recentProjects.isEmpty {
                    Divider().padding(.horizontal, DesignTokens.Spacing.sm)
                }
            }

            // 最近项目
            ForEach(recentProjects) { project in
                DropdownItemView(
                    icon: "folder",
                    iconColor: AppUI.Color.semantic.textSecondary,
                    title: project.name,
                    subtitle: project.path,
                    isCurrent: false,
                    action: {
                        onSelect(project)
                    }
                )
            }

            // 浏览按钮
            if recentProjects.isEmpty && projectVM.currentProjectPath.isEmpty {
                Text(String(localized: "No recent projects", table: "RecentProjects"))
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .padding()
            }

            Divider().padding(.horizontal, DesignTokens.Spacing.sm)

            // 打开文件选择器
            BrowseRowView(isFileImporterPresented: $isFileImporterPresented)
        }
        .padding()
        .frame(width: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .shadow(color: Color.black.opacity(0.15), radius: 12, y: 4)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

// MARK: - File Import

private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                let path = url.path
                let project = Project(name: url.lastPathComponent, path: path)
                Task { @MainActor in
                    projectVM.switchProject(to: project)
                    isPresented = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            BreadcrumbPlugin.logger.error("File import 错误：\(error.localizedDescription)")
        }
    }
}

// MARK: - Dropdown Item View

private struct DropdownItemView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isCurrent: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppUI.Typography.body)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .fill(hoverBackgroundColor)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                isHovered = hovering
            }
        }
    }

    private var hoverBackgroundColor: Color {
        if isCurrent {
            return isHovered ? Color.accentColor.opacity(0.12) : Color.accentColor.opacity(0.06)
        } else {
            return isHovered ? Color.black.opacity(0.08) : Color.clear
        }
    }
}
