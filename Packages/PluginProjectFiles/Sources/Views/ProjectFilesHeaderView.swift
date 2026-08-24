import KernelLumi
import LumiUI
import SwiftUI

/// 已打开文件标签栏（PanelHeader）。
///
/// Phase 3 迁移（重构方案 §17.2）：数据源从 `ProjectProviding` 的
/// 打开文件列表改为 `kernel.editorV2.sessions` 的 Editor Session 快照
/// （单一事实源）；激活/关闭/关闭其它走同一 Session API。
/// 只保留对 `project.currentProject` 的读取用于"是否打开了项目"的空态判断。
public struct ProjectFilesHeaderView: View {
    let kernel: KernelLumi

    @EnvironmentObject private var themeVM: AppThemeVM
    @StateObject private var editorObserver: ProjectFilesEditorObserver

    public init(kernel: KernelLumi) {
        self.kernel = kernel
        _editorObserver = StateObject(wrappedValue: ProjectFilesEditorObserver(kernel: kernel))
    }

    private var tabItems: [ProjectFilesState.TabItem] {
        ProjectFilesState.tabItems(from: editorObserver.workbenchState)
    }

    private var currentFileURL: URL? {
        ProjectFilesState.activeFileURL(from: editorObserver.workbenchState)
    }

    public var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            if kernel.project?.currentProject != nil, !tabItems.isEmpty {
                filesScrollView()
            } else {
                emptyState
            }
        }
        .borderBottom()
    }

    private var emptyState: some View {
        HStack {
            Text(kernel.project?.currentProject == nil ? "No project open" : "No files open")
                .font(.appMicro)
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
            Spacer()
        }
    }

    private func filesScrollView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabItems) { item in
                    ProjectFileItemView(
                        fileURL: item.uri,
                        isCurrent: currentFileURL == item.uri,
                        theme: themeVM.activeChromeTheme,
                        onSelect: {
                            activate(sessionID: item.id)
                        },
                        onClose: {
                            close(sessionID: item.id)
                        },
                        onCloseOthers: {
                            closeOthers(keeping: item.id)
                        }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Session 操作（统一走 kernel.editorV2）

    private func activate(sessionID: EditorSessionID) {
        kernel.editorV2?.sessions.activate(sessionID: sessionID)
    }

    private func close(sessionID: EditorSessionID) {
        Task { @MainActor in
            // 有未保存修改时先保存再关闭（旧 project.closeFile 语义只改列表；
            // Phase 3 起真正关闭 Editor Session，保存策略避免丢改动）。
            try? await kernel.editorV2?.sessions.close(sessionID: sessionID, policy: .saveFirst)
        }
    }

    private func closeOthers(keeping sessionID: EditorSessionID) {
        Task { @MainActor in
            try? await kernel.editorV2?.sessions.closeOthers(keeping: sessionID)
        }
    }
}
