import AppKit
import os
import KitHTMLPreview
import KitPrototype
import LumiUI
import ProviderToast
import SwiftUI

/// 原型设计器主面板：展示当前选中屏幕的预览 / HTML 源码，并支持导出。
public struct PrototypeDesignerView: View {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.prototype-designer",
        category: "ConversationSend"
    )
    enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace: WorkspaceStore
    @State private var mode: Mode = .preview
    @State private var isExporting = false
    /// 待确认覆盖的导出目录。
    @State private var pendingExportDirectory: URL?
    /// 与待导出目录冲突的文件名。
    @State private var pendingExportConflicts: [String] = []
    @State private var isConfirmingOverwrite = false
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
                AppEmptyState(
                    icon: "rectangle.on.rectangle.angled",
                    title: PrototypeLocalization.string("Ask the Agent to create a prototype.")
                )
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
        .onChange(of: workspace.projects.count) { _ in notifyProjectAvailability() }
        .alert(
            PrototypeLocalization.string("Operation Failed"),
            isPresented: errorBinding
        ) {
            Button(PrototypeLocalization.string("OK"), role: .cancel) { workspace.lastError = nil }
        } message: {
            Text(workspace.lastError ?? "")
        }
        .confirmationDialog(
            PrototypeLocalization.string("Some files already exist in the destination folder."),
            isPresented: $isConfirmingOverwrite
        ) {
            Button(PrototypeLocalization.string("Overwrite")) {
                Task { await confirmOverwrite() }
            }
            Button(PrototypeLocalization.string("Cancel"), role: .cancel) {
                cancelOverwrite()
            }
        } message: {
            Text(overwriteConflictMessage)
        }
    }

    /// 覆盖确认弹窗的正文：列出冲突文件名。
    private var overwriteConflictMessage: String {
        let header = PrototypeLocalization.string("The following files will be replaced:")
        return "\(header)\n\(pendingExportConflicts.joined(separator: "\n"))"
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
                    onElementReferenceSelected: { reference in
                        sendElementToConversation(reference, resolved: resolved)
                    },
                    isElementReferenceActionEnabled: PrototypeDesignerRuntime.conversationInput != nil
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
    ///
    /// 目标目录里已有同名文件时先让用户确认，避免静默覆盖用户的文件。
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

        let filenames = PrototypeExportNaming.filenames(for: project)
        let conflicts = PrototypeExportNaming.existingConflicts(
            in: directory,
            filenames: filenames
        )
        if !conflicts.isEmpty {
            pendingExportDirectory = directory
            pendingExportConflicts = conflicts
            isConfirmingOverwrite = true
            return
        }

        await performExport(to: directory, project: project)
    }

    /// 导出已确认的目录。
    @MainActor
    private func performExport(to directory: URL, project: PrototypeProject) async {
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
                let filename = PrototypeExportNaming.filename(for: screen)
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

    /// 用户确认覆盖后继续导出。
    @MainActor
    private func confirmOverwrite() async {
        guard let directory = pendingExportDirectory,
              let project = workspace.selectedProject else { return }
        pendingExportDirectory = nil
        pendingExportConflicts = []
        await performExport(to: directory, project: project)
    }

    /// 用户取消覆盖，放弃本次导出。
    @MainActor
    private func cancelOverwrite() {
        pendingExportDirectory = nil
        pendingExportConflicts = []
    }

    @MainActor
    private func sendElementToConversation(
        _ reference: HTMLPreviewElementReference,
        resolved: PrototypeResolvedScreen
    ) {
        let input = PrototypeDesignerRuntime.conversationInput
        let toast = PrototypeDesignerRuntime.toast
        let outcome = PrototypeElementConversationAction.apply(
            resolved: resolved,
            selectedProjectID: workspace.selectedProjectID,
            selectedScreenID: workspace.selectedScreenID,
            input: input
        )
        Self.logger.info("send element outcome=\(String(describing: outcome)) input=\(input != nil) toast=\(toast != nil)")
        print("[PrototypeDesigner] send element outcome=\(outcome) input=\(input != nil) toast=\(toast != nil)")
        switch outcome {
        case .appended:
            // 聚焦输入框作为兜底反馈：即使用户看不到 toast，也能看到路径进入输入区。
            input?.isInputFocused = true
            toast?.show(
                PrototypeLocalization.string("Sent to Conversation"),
                detail: resolved.screen.title,
                style: .success
            )
        case .unavailable:
            toast?.show(
                PrototypeLocalization.string("Conversation input is unavailable."),
                style: .error
            )
        case .staleSelection:
            toast?.show(
                PrototypeLocalization.string("Selection changed; please try again."),
                style: .warning
            )
        }
    }
}

// MARK: - 预览

#Preview {
    PrototypeDesignerView(workspace: WorkspaceStore.shared)
        .frame(width: 800, height: 600)
}
