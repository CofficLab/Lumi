#if os(iOS)
import Combine
import SwiftUI

/// Factory 与 BookletMaker 业务之间的窄接口。Factory 负责导航与布局，
/// 该类只暴露组装界面所需的状态和业务操作。
@MainActor
public final class BookletMakerMobileFeature: ObservableObject {
    public enum Tool: String, CaseIterable, Identifiable, Sendable {
        case split
        case booklet

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .split: "Split PDF"
            case .booklet: "Booklet"
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
    private var observation: AnyCancellable?

    public init() {
        let viewModel = BookletMakerViewModel()
        self.viewModel = viewModel
        observation = viewModel.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    public var selectedTool: Tool {
        get { viewModel.selectedTool == .split ? .split : .booklet }
        set {
            viewModel.selectedTool = newValue == .split ? .split : .booklet
            viewModel.errorMessage = nil
            objectWillChange.send()
        }
    }

    public var documentName: String {
        viewModel.currentDocument.isDemo
            ? "Sample PDF"
            : viewModel.currentDocument.url.lastPathComponent
    }
    public var pageCount: Int { viewModel.currentDocument.pageCount }
    public var isDemo: Bool { viewModel.currentDocument.isDemo }
    public var isWorking: Bool { viewModel.isRendering }
    public var progress: Double { viewModel.progress }
    public var canExport: Bool { viewModel.canExport }
    public var errorMessage: String? { viewModel.errorMessage }
    public var outputSummary: String {
        switch selectedTool {
        case .split: "\(viewModel.splitSegments.count) PDF files"
        case .booklet: "\(viewModel.expectedSheetCount) sheets"
        }
    }

    public func loadPDF(_ url: URL) async { await viewModel.loadPDF(url) }
    public func clearDocument() { viewModel.clear() }
    public func cancel() { viewModel.cancel() }

    public func makeContentView() -> AnyView {
        switch selectedTool {
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
        switch selectedTool {
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
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("booklet-split-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            await viewModel.exportSplit(to: directory)
            if !viewModel.lastSplitOutputURLs.isEmpty {
                SharePresenter.share(fileURL: directory)
            }
        }
    }
}
#endif
