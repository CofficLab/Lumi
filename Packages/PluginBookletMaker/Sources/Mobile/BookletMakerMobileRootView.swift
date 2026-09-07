#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// BookletMaker 移动端根视图。
///
/// 每个 scene 对应一个移动会话：`@StateObject` 持有 feature（业务 VM +
/// 工作区状态机 + 文件生命周期），系统文件选择器、导出结果页、
/// 分享面板与保存到文件统一在此挂载，避免 App 与 Mobile 各嵌一层
/// NavigationStack。
public struct BookletMakerMobileRootView: View {
    @StateObject public var feature: BookletMakerMobileFeature
    @State private var isImporterPresented = false
    @State private var saveDocument: PDFFileDocument?
    @State private var saveFilename = "booklet"
    @State private var isSavingPresented = false

    public init(feature: BookletMakerMobileFeature) {
        _feature = StateObject(wrappedValue: feature)
    }

    public var body: some View {
        NavigationStack {
            content
                .fileImporter(
                    isPresented: $isImporterPresented,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    guard case .success(let urls) = result, let url = urls.first else {
                        return // 选择器取消：不改变当前内容
                    }
                    Task { @MainActor in
                        await feature.importDocument(from: url)
                    }
                }
        }
        .sheet(item: exportOutcomeBinding) { outcome in
            BookletExportResultMobileView(feature: feature, outcome: outcome)
        }
        .sheet(item: presentationBinding) { presentation in
            switch presentation {
            case .shareBooklet(let url):
                SharePresenter.ShareSheet(urls: [url])
                    .presentationDetents([.medium, .large])
            case .shareSplit(let urls):
                SharePresenter.ShareSheet(urls: urls)
                    .presentationDetents([.medium, .large])
            case .saveSplit(let urls):
                SharePresenter.ShareSheet(urls: urls)
                    .presentationDetents([.medium, .large])
            case .saveBooklet(let url):
                // 单文件：直接进入系统“保存到文件”对话框。
                Color.clear
                    .onAppear {
                        saveDocument = PDFFileDocument(url: url)
                        saveFilename = url.deletingPathExtension().lastPathComponent
                        isSavingPresented = true
                        feature.workspace.present(nil)
                    }
            case .bookletOptions, .splitBatchInput, .splitRename, .help:
                EmptyView()
            }
        }
        .fileExporter(
            isPresented: $isSavingPresented,
            document: saveDocument,
            contentType: .pdf,
            defaultFilename: saveFilename
        ) { _ in
            feature.workspace.present(nil)
        }
    }

    private var exportOutcomeBinding: Binding<BookletMakerMobileFeature.ExportOutcome?> {
        Binding(
            get: { feature.exportOutcome },
            set: { newValue in
                if newValue == nil {
                    feature.dismissExportResult()
                }
            }
        )
    }

    private var presentationBinding: Binding<MobileWorkspaceState.Presentation?> {
        Binding(
            get: { feature.workspace.presentation },
            set: { feature.workspace.present($0) }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch feature.workspace.phase {
        case .welcome, .failed:
            BookletWelcomeView(feature: feature, onOpenPDF: { isImporterPresented = true })
        case .importing:
            importingView
        case .ready, .generating, .cancelling, .resultReady:
            PDFDocumentOverviewView(feature: feature, onOpenPDF: { isImporterPresented = true })
        }
    }

    private var importingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(BookletLocalization.string("Reading PDF…"))
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(BookletLocalization.string("BookletMaker"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 用于系统“保存到文件”的 PDF 文档封装。
struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    let url: URL

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url)
    }
}
#endif
