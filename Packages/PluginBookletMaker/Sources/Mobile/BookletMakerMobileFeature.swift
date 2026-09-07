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

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .split: BookletLocalization.string("Split PDF")
            case .booklet: BookletLocalization.string("Booklet")
            }
        }
        public var systemImage: String {
            switch self {
            case .split: "scissors"
            case .booklet: "book.closed"
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
        viewModel.currentDocument.isDemo
            ? BookletLocalization.string("Sample PDF")
            : viewModel.currentDocument.url.lastPathComponent
    }
    public var pageCount: Int { viewModel.currentDocument.pageCount }
    public var isDemo: Bool { viewModel.currentDocument.isDemo }
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
        sessionErrorMessage = nil
        workspace.beginImport()
        do {
            let document = try await documentStore.importPDF(from: url)
            await viewModel.loadPDF(document.url)
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
            }
        }
        set {
            switch newValue {
            case .split: workspace.selectTool(.split)
            case .booklet: workspace.selectTool(.booklet)
            }
        }
    }

    // MARK: - Export bridge

    public func cancel() { viewModel.cancel() }

    public func makeContentView() -> AnyView {
        switch workspace.selectedTool {
        case .split:
            AnyView(PDFSplitMobileView(viewModel: viewModel))
        case .booklet:
            AnyView(BookletPreviewMobileView(viewModel: viewModel))
        }
    }

    public func makeSettingsView() -> AnyView {
        AnyView(BookletMakerMobileSettingsView(viewModel: viewModel))
    }

    public func export() {
        switch workspace.selectedTool {
        case .booklet: exportBooklet()
        case .split: exportSplit()
        }
    }

    private func exportBooklet() {
        Task { @MainActor in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(viewModel.currentDocument.baseFileName)-booklet.pdf")
            try? FileManager.default.removeItem(at: url)
            await viewModel.export(to: url)
            if viewModel.lastOutputURL != nil { SharePresenter.share(fileURL: url) }
        }
    }

    private func exportSplit() {
        Task { @MainActor in
            let directory = documentStore.outputDirectory
                .appendingPathComponent("split-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            await viewModel.exportSplit(to: directory)
            if !viewModel.lastSplitOutputURLs.isEmpty {
                // T7 改为按实际文件 URL 数组分享；当前保持旧路径可用。
                SharePresenter.share(fileURL: directory)
            }
        }
    }
}
#endif
