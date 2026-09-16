import AppKit
import KitHTMLPreview
import PDFKit
import KitResume
import LumiUI
import SwiftUI

private typealias L = ResumeDesignerLocalization

/// 简历设计师主面板：展示当前选中简历的预览 / HTML 源码，
/// 支持导出矢量 PDF、分 DPI PNG 与系统打印。
public struct DesignerView: View {
    enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace: WorkspaceStore
    @State private var mode: Mode = .preview
    @State private var isExporting = false
    private let onResumeAvailabilityChanged: ((Bool) -> Void)?

    init(
        workspace: WorkspaceStore,
        onResumeAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.workspace = workspace
        self.onResumeAvailabilityChanged = onResumeAvailabilityChanged
    }

    public var body: some View {
        VStack(spacing: 0) {
            if workspace.projectResumes.isEmpty {
                emptyToolbar
                ResumeOnboardingView(isProjectOpen: workspace.projectStorageDirectory != nil)
            } else if let selected = workspace.selectedResume {
                topToolbar(for: selected.document)
                content(for: selected)
                bottomToolbar(for: selected.document)
            } else {
                ResumeTaskSelectionView(
                    message: L.string(
                        "Select a resume from the left, or ask the Agent to create one."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            notifyResumeAvailability()
        }
        .onChange(of: workspace.projectResumes.count) { _, _ in
            notifyResumeAvailability()
        }
        .alert(
            L.string("Export Failed"),
            isPresented: errorBinding
        ) {
            Button(L.string("OK"), role: .cancel) { workspace.lastError = nil }
        } message: {
            Text(workspace.lastError ?? "")
        }
    }

    private var emptyToolbar: some View {
        AppToolbarContainer {
            HStack {
                Spacer(minLength: 0)
                AppIconButton(systemImage: "arrow.clockwise", action: workspace.reload)
                    .accessibilityLabel(L.string("Refresh"))
                    .help(L.string("Refresh"))
            }
        }
        .borderBottom()
    }

    private func topToolbar(for document: ResumeDocument) -> some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.sm) {
                AppToolbarTitleLabel(icon: "doc.badge.gearshape", title: document.title)
                AppTag(L.string("In Project"), systemImage: "folder", style: .subtle)

                if let projectName = workspace.currentProjectPath?.split(separator: "/").last {
                    Text(projectName)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .borderBottom()
    }

    private func bottomToolbar(for document: ResumeDocument) -> some View {
        AppToolbarContainer {
            HStack(spacing: DesignTokens.Spacing.xs) {
                AppButton(
                    L.string("Preview"),
                    systemImage: "eye",
                    style: mode == .preview ? .primary : .ghost,
                    size: .small
                ) { mode = .preview }

                AppButton(
                    L.string("Source"),
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    style: mode == .source ? .primary : .ghost,
                    size: .small
                ) { mode = .source }

                Spacer(minLength: 0)

                AppButton(
                    L.string("Print"),
                    systemImage: "printer",
                    style: .secondary,
                    size: .small
                ) {
                    Task { await printSelectedResume() }
                }

                AppButton(
                    L.string("Export PDF"),
                    systemImage: "doc.richtext",
                    style: .secondary,
                    size: .small
                ) { exportSelectedResume(pngOnly: false) }
                    .disabled(isExporting)

                AppButton(
                    L.string("Export PNG"),
                    systemImage: "photo",
                    style: .secondary,
                    size: .small
                ) { exportSelectedResume(pngOnly: true) }
                    .disabled(isExporting)

                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.leading, DesignTokens.Spacing.xs)
                }
            }
        }
        .borderTop()
    }

    @ViewBuilder
    private func content(for resolved: ResumeResolvedDocument) -> some View {
        let preset = ResumePaperSpec.preset(for: resolved.document.paper)
        if mode == .preview {
            HTMLPreviewView(
                htmlText: resolved.html,
                fileURL: resolved.htmlURL,
                contentSize: preset.cgSize,
                onBlockSelected: { selection in
                    sendBlockToChat(selection, resolved: resolved)
                }
            )
            .id("\(resolved.document.updatedAt.timeIntervalSince1970)-\(preset.cssWidth)x\(preset.cssHeight)")
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
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { workspace.lastError != nil },
            set: { if !$0 { workspace.lastError = nil } }
        )
    }

    private func notifyResumeAvailability() {
        onResumeAvailabilityChanged?(!workspace.projectResumes.isEmpty)
    }

    /// 导出当前简历：PNG-only 模式导出 300dpi 分页 PNG，
    /// 否则同时导出矢量 PDF 与 PNG。
    private func exportSelectedResume(pngOnly: Bool) {
        guard let selected = workspace.selectedResume else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L.string("Export")
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        isExporting = true
        let storagePath = workspace.projectStoragePath
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let report = try workspace.documentStore.lintResume(
                    storagePath: storagePath,
                    slug: selected.document.id
                )
                guard report.isValid else {
                    throw ResumeStoreError.invalidHTML(report.errors)
                }
                let document = try await ResumeHTMLExporter.renderPDFDocument(
                    html: selected.html,
                    fileURL: selected.htmlURL,
                    paper: selected.document.paper
                )
                if !pngOnly, let data = document.dataRepresentation() {
                    try data.write(to: directory.appendingPathComponent("\(selected.document.id).pdf"), options: .atomic)
                }
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    let data = try ResumeHTMLExporter.pngData(
                        page: page,
                        paper: selected.document.paper,
                        dpi: ResumeExportResolution.print.rawValue
                    )
                    let filename = String(format: "%@-p%02d.png", selected.document.id, pageIndex + 1)
                    try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
                }
                workspace.lastExportURL = directory
                workspace.lastError = nil
            } catch {
                workspace.setError(error)
            }
        }
    }

    /// 系统打印：导出管线生成的 PDF 页面即物理纸张尺寸，天然无缩放。
    @MainActor
    private func printSelectedResume() async {
        guard let selected = workspace.selectedResume else { return }
        do {
            let document = try await ResumeHTMLExporter.renderPDFDocument(
                html: selected.html,
                fileURL: selected.htmlURL,
                paper: selected.document.paper
            )
            let pdfView = PDFView()
            pdfView.document = document
            let printInfo = NSPrintInfo.shared
            pdfView.print(with: printInfo, autoRotate: true, pageScaling: .pageScaleToFit)
        } catch {
            workspace.setError(error)
        }
    }

    /// 把右键选中的区块连同上下文组装成草稿，写入聊天输入框等待发送。
    @MainActor
    private func sendBlockToChat(_ selection: PromoBlockSelection, resolved: ResumeResolvedDocument) {
        guard let input = ResumeDesignerRuntime.conversationInput else { return }

        let draft = """
        帮我改一下这份简历的「\(selection.label)」区块。

        简历：\(resolved.document.title)（\(resolved.document.paper.rawValue.uppercased())）
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

#Preview {
    DesignerView(workspace: WorkspaceStore.shared)
        .frame(width: 800, height: 600)
}
