import AppKit
import HTMLPreviewKit
import PDFKit
import ResumeKit
import SwiftUI

/// 简历设计师主面板：展示当前选中简历的预览 / HTML 源码，
/// 支持导出矢量 PDF、分 DPI PNG 与系统打印。
public struct ResumeDesignerView: View {
    enum Mode: String, CaseIterable { case preview, source }

    @ObservedObject private var workspace = WorkspaceStore.shared
    @State private var mode: Mode = .preview
    @State private var isExporting = false

    // MARK: - 初始化

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            if workspace.selectedResume != nil {
                toolbar
            } else {
                emptyToolbar
            }
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { workspace.reload() }
        .alert(
            ResumeLocalization.string("Export Failed"),
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
        if let resolved = workspace.selectedResume {
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
        } else {
            ResumeEmptyStateView(
                message: ResumeLocalization.string("Ask the Agent to create a resume.")
            )
        }
    }

    private var emptyToolbar: some View {
        HStack {
            Spacer()
            Button { workspace.reload() } label: {
                Label(ResumeLocalization.string("Refresh"), systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { item in
                    Text(item == .preview
                         ? ResumeLocalization.string("Preview")
                         : ResumeLocalization.string("Source"))
                        .tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            Spacer()
            if let paper = workspace.selectedResume?.document.paper {
                Text(paper.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await printSelectedResume() }
            } label: {
                Label(ResumeLocalization.string("Print"), systemImage: "printer")
            }
            Button { exportSelectedResume(pngOnly: false) } label: {
                Label(ResumeLocalization.string("Export PDF"), systemImage: "doc.richtext")
            }
            Button { exportSelectedResume(pngOnly: true) } label: {
                Label(ResumeLocalization.string("Export PNG"), systemImage: "photo")
            }
            .disabled(isExporting)
            if isExporting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - 计算属性

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { workspace.lastError != nil },
            set: { if !$0 { workspace.lastError = nil } }
        )
    }

    // MARK: - 私有方法

    /// 导出当前简历：PNG-only 模式导出 300dpi 分页 PNG，
    /// 否则同时导出矢量 PDF 与 PNG。
    private func exportSelectedResume(pngOnly: Bool) {
        guard let selected = workspace.selectedResume else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = ResumeLocalization.string("Export")
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        isExporting = true
        let storagePath = workspace.appStoragePath
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
            // macOS PDFView 无 printOperation(for:)，直接经 print(with:) 弹出系统打印面板；
            // 页面即纸张尺寸，pageScaleToFit 兜底适配打印机可打印区域。
            pdfView.print(with: printInfo, autoRotate: true, pageScaling: .pageScaleToFit)
        } catch {
            workspace.setError(error)
        }
    }

    /// 把右键选中的区块连同上下文组装成草稿，写入聊天输入框等待发送。
    ///
    /// 遵循"填入输入框待发送"语义：不自动发送，只预填 + 聚焦，
    /// 用户可补充说明后回车。LLM 经现有 `resume_patch_html` 工具即可定位修改。
    @MainActor
    private func sendBlockToChat(_ selection: PromoBlockSelection, resolved: ResumeResolvedDocument) {
        guard let input = Runtime.kernel?.conversationInput else { return }

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

// MARK: - 预览

#Preview {
    ResumeDesignerView()
        .frame(width: 800, height: 600)
}
