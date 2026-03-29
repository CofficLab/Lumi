import MagicKit
import SwiftUI

/// 聊天消息列表视图组件
struct ChatMessagesView: View {
    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM
    @EnvironmentObject var projectVM: ProjectVM
    @State private var isProjectDropTargeted = false

    var body: some View {
        Group {
            if ConversationVM.selectedConversationId != nil {
                MessageListView()
            } else {
                EmptyStateView()
            }
        }
        .background(.background.opacity(0.6))
        .dropDestination(
            for: URL.self,
            action: { urls, _ in
                handleProjectFolderDrop(urls: urls)
            },
            isTargeted: { isTargeted in
                isProjectDropTargeted = isTargeted
            }
        )
        .overlay {
            if isProjectDropTargeted {
                projectDropOverlay
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("聊天消息区域")
    }

    private var projectDropOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(Color.black.opacity(0.12))
                .overlay(
                    Rectangle()
                        .stroke(
                            Color.accentColor.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                        )
                )

            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("松开即可添加项目")
                    .font(.system(size: 18, weight: .semibold))
                Text("将文件夹拖到消息列表区域，自动切换为当前项目")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
        }
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.15), value: isProjectDropTargeted)
    }

    private func handleProjectFolderDrop(urls: [URL]) -> Bool {
        let normalizedURLs = urls.map(\.standardizedFileURL)
        guard let folderURL = normalizedURLs.first(where: { isDirectory($0) }) else {
            return false
        }

        let project = Project(
            name: folderURL.lastPathComponent,
            path: folderURL.path,
            lastUsed: Date()
        )

        var recentProjects = projectVM.getRecentProjects()
        recentProjects.removeAll { $0.path == project.path }
        recentProjects.insert(project, at: 0)
        projectVM.setRecentProjects(Array(recentProjects.prefix(5)))
        projectVM.switchProject(to: project)
        return true
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}

// MARK: - Preview

#Preview("ChatMessagesView - Small") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("ChatMessagesView - Large") {
    ChatMessagesView()
        .padding()
        .withDebugBar()
        .background(Color.black)
        .inRootView()
        .frame(width: 1200, height: 1200)
}
