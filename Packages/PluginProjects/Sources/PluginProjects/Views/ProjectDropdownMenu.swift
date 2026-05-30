import SwiftUI
import LumiCoreKit
import LumiUI

/// 项目下拉菜单

public struct ProjectDropdownMenu: View {
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var recentProjectsVM: AppProjectsVM
    @Binding var isPresented: Bool

    public let onSelect: (Project) -> Void

    @State private var isFileImporterPresented = false

    private let store = ProjectsStore()

    private var recentProjects: [Project] {
        Array(recentProjectsVM.recentProjects
            .prefix(10)
            .filter { $0.path != projectVM.currentProjectPath })
    }

    public var body: some View {
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
                    Divider().padding(.horizontal, 8)
                }
            }

            // 最近项目
            ForEach(recentProjects) { project in
                DropdownItemView(
                    icon: "folder",
                    iconColor: Color.adaptive(light: "6B6B7B", dark: "EBEBF5"),
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
                Text(String(localized: "No projects", table: "Projects"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "98989E"))
                    .padding()
            }

            Divider().padding(.horizontal, 8)

            // 打开文件选择器
            BrowseRowView(isFileImporterPresented: $isFileImporterPresented)
        }
        .padding()
        .frame(width: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    projectVM.switchProject(to: project, reason: "projectDropdownSelect")
                    isPresented = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            if ProjectsPlugin.verbose {
                            ProjectsPlugin.logger.error("File import error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Dropdown Item View

private struct DropdownItemView: View {
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let subtitle: String
    public let isCurrent: Bool
    public let action: () -> Void

    public var body: some View {
        AppListRow(isSelected: isCurrent, action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "98989E"))
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
        }
    }
}
