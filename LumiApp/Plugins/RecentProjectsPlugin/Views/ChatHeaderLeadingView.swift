import MagicKit
import SwiftUI

/// 头部左侧视图：应用图标、当前项目名（支持下拉选择）
struct ChatHeaderLeadingView: View {
    @EnvironmentObject var projectVM: ProjectVM

    @State private var isDropdownPresented = false
    @State private var hoverState = false

    private let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.accentColor)
                .padding(4)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())

            Text(projectVM.currentProjectName.isEmpty ? "Lumi" : projectVM.currentProjectName)
                .font(AppUI.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
                .rotationEffect(.degrees(isDropdownPresented ? 180 : 0))
                .animation(.easeInOut(duration: DesignTokens.Duration.micro), value: isDropdownPresented)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm))
        .overlay(borderOverlay)
        .onHover { hovering in
            hoverState = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleDropdown()
        }
        .overlay(alignment: .topLeading) {
            dropdownContent
        }
        .onOpenProjectSelector {
            isDropdownPresented = true
        }
    }

    // MARK: - Hover State

    private var backgroundColor: Color {
        if isDropdownPresented {
            return Color.accentColor.opacity(0.08)
        } else if hoverState {
            return Color.black.opacity(0.05)
        } else {
            return Color.clear
        }
    }

    private var borderOverlay: some View {
        Group {
            if isDropdownPresented || hoverState {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                    .stroke(Color.accentColor.opacity(isDropdownPresented ? 0.4 : 0.15), lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: DesignTokens.Duration.micro), value: isDropdownPresented)
        .animation(.easeOut(duration: DesignTokens.Duration.micro), value: hoverState)
    }

    // MARK: - Dropdown

    private var dropdownContent: some View {
        Group {
            if isDropdownPresented {
                ProjectDropdownMenu(
                    isPresented: $isDropdownPresented,
                    onSelect: { project in
                        selectProject(project)
                    }
                )
                .offset(y: 32) // 下拉菜单偏移到按钮下方
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
    }

    // MARK: - Action

    private func toggleDropdown() {
        withAnimation(.easeInOut(duration: DesignTokens.Duration.standard)) {
            isDropdownPresented.toggle()
        }
    }

    private func selectProject(_ project: Project) {
        Task { @MainActor in
            projectVM.switchProject(to: project)
        }
        withAnimation(.easeInOut(duration: DesignTokens.Duration.standard)) {
            isDropdownPresented = false
        }
    }
}

// MARK: - 下拉菜单

private struct ProjectDropdownMenu: View {
    @EnvironmentObject var projectVM: ProjectVM
    @Binding var isPresented: Bool

    let onSelect: (Project) -> Void

    @State private var isFileImporterPresented = false

    private let store = RecentProjectsStore()

    private var recentProjects: [Project] {
        Array(projectVM.recentProjects
            .prefix(5)
            .filter { $0.path != projectVM.currentProjectPath })
    }

    var body: some View {
        VStack(spacing: 0) {
            // 当前项目
            if !projectVM.currentProjectPath.isEmpty {
                dropdownItem(
                    icon: "hammer.fill",
                    iconColor: .accentColor,
                    title: projectVM.currentProjectName,
                    subtitle: projectVM.currentProjectPath,
                    isCurrent: true
                ) { }

                if !recentProjects.isEmpty {
                    Divider().padding(.horizontal, DesignTokens.Spacing.sm)
                }
            }

            // 最近项目
            ForEach(recentProjects) { project in
                dropdownItem(
                    icon: "folder",
                    iconColor: AppUI.Color.semantic.textSecondary,
                    title: project.name,
                    subtitle: project.path,
                    isCurrent: false
                ) {
                    onSelect(project)
                }
            }

            // 浏览按钮
            if recentProjects.isEmpty && projectVM.currentProjectPath.isEmpty {
                Text(String(localized: "No recent projects", table: "RecentProjects"))
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                    .padding(.vertical, DesignTokens.Spacing.sm)
            }

            Divider().padding(.horizontal, DesignTokens.Spacing.sm)

            // 打开文件选择器
            browseRow
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
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

    // MARK: - Dropdown Item

    private func dropdownItem(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isCurrent: Bool,
        action: @escaping () -> Void
    ) -> some View {
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Browse Row

    private var browseRow: some View {
        Button(action: {
            isFileImporterPresented = true
        }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.accentColor)

                Text(String(localized: "Select New Project", table: "RecentProjects"))
                    .font(AppUI.Typography.body)
                    .foregroundColor(.accentColor)

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            RecentProjectsPlugin.logger.error("File import 错误：\(error.localizedDescription)")
        }
    }
}

// MARK: - Preview

#Preview("Chat Header Leading") {
    ChatHeaderLeadingView()
        .inRootView()
}
