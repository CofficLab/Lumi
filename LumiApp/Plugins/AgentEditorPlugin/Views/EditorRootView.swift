import MagicKit
import SwiftUI

/// 编辑器主视图（根入口）
/// 组合面包屑、工具栏、编辑器、状态栏
struct EditorRootView: View {

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    /// 编辑器状态
    @StateObject private var state = EditorState()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if projectVM.isFileSelected {
                    // Header 区域：面包屑 + 工具栏（带背景，覆盖编辑器）
                    headerArea

                    // 文件信息提示
                    fileInfoBanner

                    // 编辑器主体
                    editorContent
                } else {
                    // 空状态
                    emptyState
                }
            }

            if state.isReferencePanelPresented {
                EditorReferencesPanelView(state: state)
            } else if state.isProblemsPanelPresented {
                ProblemsPanelView(state: state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: projectVM.selectedFileURL) { _, newURL in
            state.projectRootPath = projectVM.currentProject?.path
            state.loadFile(from: newURL)
        }
        .onAppear {
            // 激活左侧栏的 ProjectTree 插件
            layoutVM.selectAgentSidebarTab(ProjectTreePlugin.id, reason: "Editor appeared")

            // 初始加载
            state.projectRootPath = projectVM.currentProject?.path
            if projectVM.isFileSelected {
                state.loadFile(from: projectVM.selectedFileURL)
            }
        }
        .onDisappear {
            // 切走时保存
            if state.hasUnsavedChanges {
                state.saveNow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFormatDocument)) { _ in
            guard projectVM.isFileSelected else { return }
            Task { @MainActor in
                await state.formatDocumentWithLSP()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFindReferences)) { _ in
            guard projectVM.isFileSelected else { return }
            Task { @MainActor in
                await state.showReferencesFromCurrentCursor()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorRenameSymbol)) { _ in
            guard projectVM.isFileSelected else { return }
            state.promptRenameSymbol()
        }
    }

    // MARK: - Header Area

    /// Header 区域：包含面包屑和工具栏，带背景色覆盖编辑器内容
    private var headerArea: some View {
        VStack(spacing: 0) {
            // 面包屑导航
            EditorBreadcrumbView(state: state)

            GlassDivider()

            // 工具栏（紧凑模式）
            EditorToolbarView(state: state)
        }
        // 关键：添加背景色，确保覆盖下方的编辑器内容（如行号）
        .background(
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()
        )
        // 使用 zIndex 确保 header 在编辑器上层
        .zIndex(1)
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        if state.canPreview {
            SourceEditorView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(state.currentFileURL)  // 文件切换时重建编辑器
                // 关键：裁剪溢出的内容，防止行号延伸到 header
                .clipped()
        } else if projectVM.isFileSelected {
            unsupportedFileView
        }
    }

    // MARK: - File Info Banner

    @ViewBuilder
    private var fileInfoBanner: some View {
        if state.isTruncated || !state.isEditable {
            VStack(alignment: .leading, spacing: 4) {
                if state.isTruncated {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(
                            String(
                                localized: "Preview Truncated for Large File", table: "LumiEditor")
                        )
                        .font(.system(size: 9))
                        .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }
                if !state.isEditable {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(String(localized: "Large File Read-Only Preview", table: "LumiEditor"))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppUI.Color.semantic.warning.opacity(0.06))
            // Banner 也需要覆盖下层内容
            .background(Color(nsColor: .textBackgroundColor))
            .zIndex(1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Code Editor", table: "LumiEditor"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Text(String(localized: "Select a file to start editing", table: "LumiEditor"))
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Unsupported File

    private var unsupportedFileView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Unsupported File", table: "LumiEditor"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Text(state.fileName)
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Preview

#Preview {
    EditorRootView()
        .inRootView()
}
