import SwiftUI
import UniformTypeIdentifiers

/// 项目选择器视图
struct ProjectSelectorView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @Binding var isPresented: Bool

    @State private var recentProjects: [RecentProject] = []
    @State private var isFileImporterPresented = false

    private let maxRecentProjects = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("选择项目")
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
                VStack(alignment: .leading, spacing: 16) {
                    // Current Project Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前项目")
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
                            Text("最近项目")
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
                        Text("浏览")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                            .padding(.horizontal)

                        browseButton
                    }
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadRecentProjects()
        }
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
                    Text(viewModel.currentProjectName.isEmpty ? "未选择项目" : viewModel.currentProjectName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text(viewModel.currentProjectPath.isEmpty ? "点击下方浏览选择项目" : viewModel.currentProjectPath)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding()
        }
        .padding(.horizontal)
    }

    // MARK: - Project Card

    private func projectCard(_ project: RecentProject) -> some View {
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
                    .padding()
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

                Text("选择新项目...")
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

    // MARK: - Actions

    private func selectProject(_ project: RecentProject) {
        Task { @MainActor in
            viewModel.switchProject(to: project.path)
            isPresented = false
        }
    }

    private func deleteProject(_ project: RecentProject) {
        withAnimation {
            recentProjects.removeAll { $0.id == project.id }
            saveRecentProjects()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    return
                }

                let path = url.path
                Task { @MainActor in
                    viewModel.switchProject(to: path)
                    isPresented = false
                    // Reload recent projects
                    loadRecentProjects()
                }

                // Stop accessing after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        case .failure(let error):
            print("File import 错误：\(error)")
        }
    }

    private func loadRecentProjects() {
        // 使用 AgentProvider 加载最近项目
        recentProjects = AgentProvider.shared.getRecentProjects()
            .prefix(maxRecentProjects)
            .filter { project in
                // 过滤掉当前项目
                project.path != viewModel.currentProjectPath
            }
    }

    private func saveRecentProjects() {
        // 直接保存到 UserDefaults
        if let encoded = try? JSONEncoder().encode(recentProjects) {
            UserDefaults.standard.set(encoded, forKey: "Agent_RecentProjects")
        }
    }
}

// MARK: - Preview

#Preview("Project Selector") {
    ProjectSelectorView(
        viewModel: AssistantViewModel(),
        isPresented: .constant(true)
    )
}
