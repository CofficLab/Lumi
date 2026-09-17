import AppKit
import KitHTMLPreview
import KitPrototype
import LumiUI
import SwiftUI

/// 原型设计器主面板：展示当前选中屏幕的预览 / HTML 源码，并支持导出。
public struct PrototypeDesignerView: View {
    enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace: WorkspaceStore
    @State private var mode: Mode = .preview
    @State private var isExporting = false
    private let onProjectAvailabilityChanged: ((Bool) -> Void)?

    // MARK: - 初始化

    init(
        workspace: WorkspaceStore,
        onProjectAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.workspace = workspace
        self.onProjectAvailabilityChanged = onProjectAvailabilityChanged
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            if workspace.projects.isEmpty {
                emptyToolbar
                PrototypeOnboardingView(isProjectOpen: workspace.projectStorageDirectory != nil)
            } else if let resolved = workspace.selectedScreen {
                PrototypeDesignerTopToolbar(
                    workspace: workspace,
                    screen: resolved.screen,
                    onRefresh: { workspace.reload() }
                )
                content
                PrototypeDesignerBottomToolbar(
                    mode: $mode,
                    isExporting: isExporting,
                    onExport: { Task { await exportSelectedProject() } }
                )
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { notifyProjectAvailability() }
        .onChange(of: workspace.projects.count) { _, _ in notifyProjectAvailability() }
        .alert(
            PrototypeLocalization.string("Export Failed"),
            isPresented: errorBinding
        ) {
            Button(PrototypeLocalization.string("OK"), role: .cancel) { workspace.lastError = nil }
        } message: {
            Text(workspace.lastError ?? "")
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var content: some View {
        if let resolved = workspace.selectedScreen {
            if mode == .preview {
                HTMLPreviewView(
                    htmlText: resolved.html,
                    fileURL: resolved.htmlURL,
                    contentSize: resolved.project.device.logicalSize,
                    onBlockSelected: { selection in
                        sendBlockToChat(selection, resolved: resolved)
                    }
                )
                .id("\(resolved.screen.updatedAt.timeIntervalSince1970)-\(resolved.project.device.kind.rawValue)")
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(resolved.html)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(18)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        } else {
            PrototypeSelectionView(
                message: PrototypeLocalization.string(
                    "Select a screen from the left, or ask the Agent to create a prototype."
                )
            )
        }
    }

    @ViewBuilder
    private var emptyToolbar: some View {
        AppToolbarContainer {
            HStack {
                Spacer(minLength: 0)
                AppIconButton(systemImage: "arrow.clockwise", action: workspace.reload)
                    .accessibilityLabel(PrototypeLocalization.string("Refresh"))
                    .help(PrototypeLocalization.string("Refresh"))
            }
        }
        .borderBottom()
    }

    // MARK: - 计算属性

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { workspace.lastError != nil },
            set: { if !$0 { workspace.lastError = nil } }
        )
    }

    // MARK: - 私有方法

    private func notifyProjectAvailability() {
        onProjectAvailabilityChanged?(!workspace.projects.isEmpty)
    }

    /// 把整个原型项目的每一屏渲染成 PNG 导出到用户选择的目录。
    @MainActor
    private func exportSelectedProject() async {
        guard let project = workspace.selectedProject, !project.screens.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = PrototypeLocalization.string("Export")
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        isExporting = true
        defer { isExporting = false }
        do {
            let storagePath = workspace.projectStoragePath
            let device = project.device
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for screen in project.sortedScreens {
                let resolved = try workspace.documentStore.readScreen(
                    storagePath: storagePath,
                    projectSlug: project.id,
                    screenSlug: screen.id
                )
                let report = try workspace.documentStore.lintScreen(
                    storagePath: storagePath,
                    projectSlug: project.id,
                    screenSlug: screen.id
                )
                guard report.isValid else { throw PrototypeStoreError.invalidHTML(report.errors) }
                let data = try await PrototypeHTMLExporter.exportPNG(
                    html: resolved.html,
                    fileURL: resolved.htmlURL,
                    device: device
                )
                let filename = String(format: "%02d-%@.png", screen.order + 1, screen.id)
                try data.write(
                    to: directory.appendingPathComponent(filename),
                    options: .atomic
                )
            }
            workspace.lastExportURL = directory
            workspace.lastError = nil
        } catch {
            workspace.setError(error)
        }
    }

    /// 把右键选中的区块连同上下文组装成草稿，写入聊天输入框等待发送。
    ///
    /// 遵循「填入输入框待发送」语义：不自动发送，只预填 + 聚焦，用户可补充说明后回车。
    @MainActor
    private func sendBlockToChat(_ selection: PromoBlockSelection, resolved: PrototypeResolvedScreen) {
        guard let input = PrototypeDesignerRuntime.conversationInput else { return }

        let draft = """
        帮我改一下这屏原型的「\(selection.label)」区块。

        原型项目：\(resolved.project.title)（\(resolved.project.id)）
        屏幕：\(resolved.screen.title)（\(resolved.screen.id)）
        设备：\(resolved.project.device.kind.displayName)
        区块标识：\(selection.blockID)

        当前该区块的 HTML：
        ```html
        \(selection.outerHTML)
        ```
        """

        if input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input.text = draft
        } else {
            input.text = input.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + draft
        }
        input.isInputFocused = true
    }
}

// MARK: - 预览

#Preview {
    PrototypeDesignerView(workspace: WorkspaceStore.shared)
        .frame(width: 800, height: 600)
}
