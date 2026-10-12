#if os(iOS)
import Combine
import SwiftUI

/// Factory 与 BookletMaker 业务之间的窄接口。
///
/// 该类型拥有移动会话：共享业务状态（`BookletMakerViewModel`）、移动工作区
/// 状态机（`MobileWorkspaceState`）与文件生命周期（`MobileDocumentStore`）。
/// 所有局部页面只接收同一个 feature 实例。
@MainActor
public final class BookletMakerMobileFeature: ObservableObject {
    public enum Tool: String, CaseIterable, Identifiable, Sendable {
        case split
        case booklet
        case merge

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .split: BookletLocalization.string("Split PDF")
            case .booklet: BookletLocalization.string("Booklet")
            case .merge: BookletLocalization.string("Merge PDF")
            }
        }
        public var systemImage: String {
            switch self {
            case .split: "scissors"
            case .booklet: "book.closed"
            case .merge: "arrow.triangle.merge"
            }
        }
    }

    let viewModel: BookletMakerViewModel
    let workspace: MobileWorkspaceState
    let documentStore: MobileDocumentStore
    private var observation: BookletMakerFeatureObserver?

    /// Import / session errors surfaced inline. Business errors live in
    /// `viewModel.errorMessage`.
    @Published private(set) var sessionErrorMessage: String?

    /// The outcome of the most recent export, driving the result sheet.
    @Published private(set) var exportOutcome: ExportOutcome?

    enum ExportOutcome: Identifiable, Equatable {
        case success(urls: [URL])
        case failure(message: String)

        var id: String {
            switch self {
            case .success(let urls): "success-\(urls.map(\.path).joined(separator: "|"))"
            case .failure(let message): "failure-\(message)"
            }
        }
    }

    public init() {
        let viewModel = BookletMakerViewModel()
        self.viewModel = viewModel
        workspace = MobileWorkspaceState()
        documentStore = MobileDocumentStore()
        observation = BookletMakerFeatureObserver(viewModel: viewModel) { [weak self] in
            self?.objectWillChange.send()
        }
        MobileDocumentStore.cleanupStaleSessions(keeping: documentStore)
    }

    // MARK: - Document access

    public var documentName: String {
        if workspace.selectedTool == .merge, !viewModel.mergeDocuments.isEmpty {
            return BookletLocalization.string(
                "%lld PDF files",
                Int64(viewModel.mergeDocuments.count)
            )
        }
        viewModel.currentDocument.isDemo
            ? BookletLocalization.string("Sample PDF")
            : viewModel.currentDocument.url.lastPathComponent
    }
    public var pageCount: Int {
        workspace.selectedTool == .merge && !viewModel.mergeDocuments.isEmpty
            ? viewModel.mergePageCount
            : viewModel.currentDocument.pageCount
    }
    public var mergePageCount: Int { viewModel.mergePageCount }
    public var mergeDocumentCount: Int { viewModel.mergeDocuments.count }
    public var documentPreviewURL: URL {
        viewModel.mergeDocuments.first?.url ?? viewModel.currentDocument.url
    }
    public var isDemo: Bool {
        workspace.selectedTool != .merge || viewModel.mergeDocuments.isEmpty
            ? viewModel.currentDocument.isDemo
            : false
    }
    public var isWorking: Bool { viewModel.isBusy }
    public var progress: Double { viewModel.progress }
    public var canExport: Bool { viewModel.canExport }
    public var errorMessage: String? { viewModel.errorMessage }
    public var outputSummary: String {
        switch workspace.selectedTool {
        case .split:
            BookletLocalization.string("%lld PDF files", Int64(viewModel.splitSegments.count))
        case .booklet:
            BookletLocalization.string("%lld sheets", Int64(viewModel.expectedSheetCount))
        case .merge:
            BookletLocalization.string(
                "%lld files · %lld pages",
                Int64(viewModel.mergeDocuments.count),
                Int64(viewModel.mergePageCount)
            )
        }
    }

    // MARK: - Document lifecycle

    /// Open the built-in sample document (an explicit, active choice).
    public func openSampleDocument() {
        viewModel.clear()
        sessionErrorMessage = nil
        workspace.documentReady()
    }

    /// Import a PDF picked by the system file picker.
    ///
    /// The store copies and validates the file before the view model adopts
    /// it, so a failed import never loses the previous document or its
    /// editing state.
    public func importDocument(from url: URL) async {
        await importDocuments(from: [url])
    }

    /// Import and validate an ordered group of PDFs for the merge tool.
    public func importDocuments(from urls: [URL]) async {
        sessionErrorMessage = nil
        workspace.beginImport()
        do {
            let documents = try await documentStore.importPDFs(from: urls)
            if workspace.selectedTool == .merge {
                await viewModel.loadMergePDFs(
                    documents.map(\.url),
                    appending: !viewModel.mergeDocuments.isEmpty
                )
            } else if let document = documents.first {
                await viewModel.loadPDF(document.url)
            }
            if viewModel.errorMessage == nil {
                workspace.documentReady()
            } else {
                workspace.documentFailed()
            }
        } catch {
            sessionErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            workspace.documentFailed()
        }
    }

    /// Close the current document and return to the welcome screen.
    public func closeDocument() {
        viewModel.clear()
        documentStore.clearSession()
        sessionErrorMessage = nil
        workspace.closeDocument()
    }

    public func dismissSessionError() {
        sessionErrorMessage = nil
        workspace.dismissFailure()
    }

    // MARK: - Tool routing

    public var selectedTool: Tool {
        get {
            switch workspace.selectedTool {
            case .split: .split
            case .booklet: .booklet
            case .merge: .merge
            }
        }
        set {
            switch newValue {
            case .split: workspace.selectTool(.split)
            case .booklet: workspace.selectTool(.booklet)
            case .merge: workspace.selectTool(.merge)
            }
        }
    }

    // MARK: - Export bridge

    public func cancel() { viewModel.cancel() }

    public func makeContentView(onOpenPDF: @escaping () -> Void = {}) -> AnyView {
        switch workspace.selectedTool {
        case .split:
            AnyView(PDFSplitMobileView(
                viewModel: viewModel,
                onExport: { [weak self] in self?.exportSplit() }
            ))
        case .booklet:
            AnyView(BookletPreviewMobileView(
                viewModel: viewModel,
                onExport: { [weak self] in self?.exportBooklet() }
            ))
        case .merge:
            AnyView(PDFMergeMobileView(
                viewModel: viewModel,
                onOpenPDF: onOpenPDF,
                onExport: { [weak self] in self?.exportMerge() }
            ))
        }
    }

    public func export() {
        switch workspace.selectedTool {
        case .booklet: exportBooklet()
        case .split: exportSplit()
        case .merge: exportMerge()
        }
    }

    private func exportBooklet() {
        Task { @MainActor in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(viewModel.currentDocument.baseFileName)-booklet.pdf")
            try? FileManager.default.removeItem(at: url)
            await viewModel.export(to: url)
            applyExportOutcome(urls: viewModel.lastOutputURL.map { [$0] } ?? [])
        }
    }

    private func exportSplit() {
        Task { @MainActor in
            let directory = documentStore.outputDirectory
                .appendingPathComponent("split-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            await viewModel.exportSplit(to: directory)
            applyExportOutcome(urls: viewModel.lastSplitOutputURLs)
        }
    }

    private func exportMerge() {
        Task { @MainActor in
            let url = documentStore.outputDirectory
                .appendingPathComponent("merged-\(UUID().uuidString).pdf")
            try? FileManager.default.createDirectory(
                at: documentStore.outputDirectory,
                withIntermediateDirectories: true
            )
            await viewModel.exportMerge(to: url)
            applyExportOutcome(urls: viewModel.lastMergeOutputURL.map { [$0] } ?? [])
        }
    }

    private func applyExportOutcome(urls: [URL]) {
        if !urls.isEmpty {
            workspace.generationFinished()
            exportOutcome = .success(urls: urls)
        } else if let message = viewModel.errorMessage {
            workspace.generationFailed()
            exportOutcome = .failure(message: message)
        } else {
            // Cancelled or silent failure: no result sheet.
            workspace.generationCancelled()
        }
    }

    // MARK: - Export result actions

    public var exportedFileCount: Int {
        if case .success(let urls) = exportOutcome { return urls.count }
        return 0
    }

    public func exportedURLs() -> [URL] {
        if case .success(let urls) = exportOutcome { return urls }
        return []
    }

    /// Present the system share sheet for the produced files.
    public func presentShare() {
        let urls = exportedURLs()
        guard !urls.isEmpty else { return }
        if urls.count == 1 {
            if workspace.selectedTool == .merge {
                workspace.present(.shareMerge(urls[0]))
            } else {
                workspace.present(.shareBooklet(urls[0]))
            }
        } else {
            workspace.present(.shareSplit(urls))
        }
    }

    /// Present a save destination for the produced files.
    public func presentSave() {
        let urls = exportedURLs()
        guard !urls.isEmpty else { return }
        if urls.count == 1 {
            if workspace.selectedTool == .merge {
                workspace.present(.saveMerge(urls[0]))
            } else {
                workspace.present(.saveBooklet(urls[0]))
            }
        } else {
            workspace.present(.saveSplit(urls))
        }
    }

    /// Close the result sheet and return to the working state.
    public func dismissExportResult() {
        exportOutcome = nil
        workspace.generationCancelled()
    }
}
#endif
