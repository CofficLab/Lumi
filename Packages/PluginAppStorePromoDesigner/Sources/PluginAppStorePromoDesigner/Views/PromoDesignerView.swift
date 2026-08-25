import AppKit
import KitAppStorePromo
import KitHTMLPreview
import LumiUI
import SwiftUI

/// 设计师主面板：展示当前选中图像的预览 / HTML 源码，并支持导出。
public struct PromoDesignerView: View {
    enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace = WorkspaceStore.shared
    @State private var mode: Mode = .preview
    @State private var isExporting = false

    // MARK: - 初始化

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            if let resolved = workspace.selectedImage {
                toolbar(for: resolved.task)
            } else {
                emptyToolbar
            }
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { workspace.reload() }
        .alert(
            PromoLocalization.string("Export Failed"),
            isPresented: errorBinding
        ) {
            Button("OK", role: .cancel) { workspace.lastError = nil }
        } message: {
            Text(workspace.lastError ?? "")
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var content: some View {
        if let resolved = workspace.selectedImage,
           let preset = AppStorePromoDisplaySpec.preset(for: workspace.selectedDisplayType) {
            if mode == .preview {
                HTMLPreviewView(
                    htmlText: resolved.html,
                    fileURL: resolved.htmlURL,
                    contentSize: preset.cgSize,
                    onBlockSelected: { selection in
                        sendBlockToChat(selection, resolved: resolved)
                    }
                )
                .id("\(resolved.image.updatedAt.timeIntervalSince1970)-\(resolved.localeIdentifier)-\(preset.displayType)")
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
            PromoDesignerEmptyState(
                message: PromoLocalization.string("Ask the Agent to create a promotional artwork task.")
            )
        }
    }

    @ViewBuilder
    private var emptyToolbar: some View {
        HStack {
            Spacer()
            Button { workspace.reload() } label: {
                Label(PromoLocalization.string("Refresh"), systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func toolbar(for task: AppStorePromoTask) -> some View {
        PromoDesignerToolbar(
            workspace: workspace,
            task: task,
            mode: $mode,
            isExporting: isExporting,
            onRefresh: { workspace.reload() },
            onExport: {
                Task { await exportSelectedTask() }
            }
        )
    }

    // MARK: - 计算属性

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { workspace.lastError != nil },
            set: { if !$0 { workspace.lastError = nil } }
        )
    }

    // MARK: - 私有方法

    @MainActor
    private func exportSelectedTask() async {
        guard let selected = workspace.selectedImage,
              let preset = AppStorePromoDisplaySpec.preset(for: workspace.selectedDisplayType) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = PromoLocalization.string("Export")
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        isExporting = true
        defer { isExporting = false }
        do {
            let storagePath = workspace.storagePath(for: workspace.selectedScope)
            let task = try workspace.documentStore.readTask(
                storagePath: storagePath,
                taskSlug: selected.task.id
            )
            let scopeSubdir = workspace.selectedScope == .project ? "project" : "app"
            let targetDirectory = directory.appendingPathComponent(scopeSubdir, isDirectory: true)
            try FileManager.default.createDirectory(
                at: targetDirectory,
                withIntermediateDirectories: true
            )
            for imageMeta in task.images.sorted(by: { $0.order < $1.order }) {
                for localeIdentifier in imageMeta.localeIdentifiers {
                    let image = try workspace.documentStore.readImage(
                        storagePath: storagePath,
                        taskSlug: task.id,
                        imageSlug: imageMeta.id,
                        localeIdentifier: localeIdentifier
                    )
                    let report = try workspace.documentStore.lintImage(
                        storagePath: storagePath,
                        taskSlug: task.id,
                        imageSlug: imageMeta.id,
                        localeIdentifier: localeIdentifier
                    )
                    guard report.isValid else {
                        throw AppStorePromoStoreError.invalidHTML(report.errors)
                    }
                    let data = try await AppStorePromoHTMLExporter.exportPNG(
                        html: image.html,
                        fileURL: image.htmlURL,
                        preset: preset
                    )
                    let localeDirectory = targetDirectory.appendingPathComponent(localeIdentifier, isDirectory: true)
                    try FileManager.default.createDirectory(at: localeDirectory, withIntermediateDirectories: true)
                    let filename = String(
                        format: "%02d-%@-%@.png",
                        imageMeta.order + 1,
                        imageMeta.id,
                        preset.displayType
                    )
                    try data.write(
                        to: localeDirectory.appendingPathComponent(filename),
                        options: .atomic
                    )
                }
            }
            workspace.lastExportURL = targetDirectory
            workspace.lastError = nil
        } catch {
            workspace.setError(error)
        }
    }

    /// 把右键选中的区块连同上下文组装成草稿，写入聊天输入框等待发送。
    ///
    /// 遵循"填入输入框待发送"语义：不自动发送，只预填 + 聚焦，用户可补充说明后回车。
    /// 草稿里包含任务/图片/区块标识与区块 HTML，LLM 经现有 `_patch_html` 工具即可定位修改。
    @MainActor
    private func sendBlockToChat(_ selection: PromoBlockSelection, resolved: AppStorePromoResolvedImage) {
        guard let input = PromoDesignerRuntime.conversationInput else { return }

        let draft = """
        帮我改一下这张促销图的「\(selection.label)」区块。

        任务：\(resolved.task.title)（\(resolved.task.deviceFamily.rawValue)）
        图片：\(resolved.image.title)
        语言：\(resolved.localeIdentifier)
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
    PromoDesignerView()
        .frame(width: 800, height: 600)
}
