import SwiftUI
import UniformTypeIdentifiers

/// 项目选择器视图
struct ProjectSelectorView: View {
    @EnvironmentObject var ProjectVM: ProjectVM
    @EnvironmentObject private var projectContextRequestVM: ProjectContextRequestVM

    @Binding var isPresented: Bool

    @State private var isFileImporterPresented = false

    private let maxRecentProjects = 5
    private let store = RecentProjectsStore()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "Select Project", table: "AgentProjectHeader"))
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(DesignTokens.Material.glassThick)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.black.opacity(0.05)),
                alignment: .bottom
            )

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    // Current Project Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Current Project", table: "AgentProjectHeader"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .padding(.horizontal)
                            .padding(.top)

                        currentProjectCard
                    }

                    // Recent Projects Section
                    if !recentProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Recent Projects", table: "AgentProjectHeader"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                .padding(.horizontal)

                            ForEach(recentProjects) { project in
                                projectCard(project)
                            }
                        }
                    }

                    // Browse Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "Browse", table: "AgentProjectHeader"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .padding(.horizontal)

                        browseButton
                    }
                    .padding(.bottom)
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Computed Properties

    private var recentProjects: [Project] {
        Array(ProjectVM.recentProjects
            .prefix(maxRecentProjects)
            .filter { project in
                project.path != ProjectVM.currentProjectPath
            })
    }

    // MARK: - Current Project Card

    private var currentProjectCard: some View {
        GlassRow {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(ProjectVM.currentProjectName.isEmpty ? String(localized: "No Project Selected", table: "AgentProjectHeader") : ProjectVM.currentProjectName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text(ProjectVM.currentProjectPath.isEmpty ? String(localized: "Click Browse Below", table: "AgentProjectHeader") : ProjectVM.currentProjectPath)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(2)
                }

                Spacer()

                // 已选择项目时显示「删除」按钮，清除后恢复到未选择状态
                if !ProjectVM.currentProjectName.isEmpty {
                    Button(action: {
                        projectContextRequestVM.request = .clearProject
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Clear Project Selection", table: "AgentProjectHeader"))
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Project Card

    private func projectCard(_ project: Project) -> some View {
        GlassRow {
            HStack(spacing: 12) {
                // 选择项目按钮
                Button(action: {
                    selectProject(project)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 20))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            Text(project.path)
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                // 删除按钮
                Button(action: {
                    deleteProject(project)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Browse Button

    private var browseButton: some View {
        Button(action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)

                Text(String(localized: "Select New Project", table: "AgentProjectHeader"))
                    .font(.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
}

// MARK: - View

// MARK: - Action

// MARK: - Setter

// MARK: - Event Handler

extension ProjectSelectorView {
    private func selectProject(_ project: Project) {
        Task { @MainActor in
            projectContextRequestVM.request = .switchProject(path: project.path)
            isPresented = false
        }
    }

    private func deleteProject(_ project: Project) {
        withAnimation {
            store.removeProject(project)
            // 更新 projectVM 中的列表
            ProjectVM.setRecentProjects(store.loadProjects())
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else {
                    return
                }

                let path = url.path
                Task { @MainActor in
                    projectContextRequestVM.request = .switchProject(path: path)
                    isPresented = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            AgentProjectHeaderPlugin.logger.error("File import 错误：\(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview("Project Selector") {
    ProjectSelectorView(isPresented: .constant(true))
        .inRootView()
}
