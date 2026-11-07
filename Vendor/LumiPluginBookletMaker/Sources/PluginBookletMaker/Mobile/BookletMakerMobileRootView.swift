#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// BookletMaker 移动端根视图。
///
/// 每个 scene 对应一个移动会话：`@StateObject` 持有 feature（业务 VM +
/// 工作区状态机 + 文件生命周期），系统文件选择器、导出结果页、
/// 分享面板与保存到文件统一在此挂载，避免 App 与 Mobile 各嵌一层
/// NavigationStack。
///
/// 主线是「首页选工具 → 全屏引导 → 直接进工作台」：首页列出三个工具，
/// 选中后以 `fullScreenCover` 铺满全屏展示分步引导，引导里完成
/// 「打开 PDF / 用示例」这一步，随后关闭 cover，工作台已经就位。
/// 中间没有额外的概览页。
public struct BookletMakerMobileRootView: View {
    @StateObject public var feature: BookletMakerMobileFeature
    @ObservedObject private var workspace: MobileWorkspaceState
    /// 宿主追加到导航栏尾部的工具栏项。
    ///
    /// 本视图内部创建了 `NavigationStack`。SwiftUI 的 `.toolbar` 只对**最近的
    /// 导航容器**生效：挂在 `NavigationStack` **外面**的 `.toolbar` 会被外层
    /// 上下文接走（没有外层导航容器时直接不显示），挂在外面的视图也不会被
    /// 传递进这条嵌套的导航栈。因此宿主（例如设置齿轮）无法从外面往这里塞
    /// 工具栏项，只能把项收集好传进来，由本视图挂到**栈内内容**上。
    public let trailingToolbarItems: [AnyView]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isImporterPresented = false
    @State private var activeGuide: BookletGuideKind?
    /// 引导打开时落在第几屏。帮助页的「再看一次引导」可以从任意一屏开始。
    @State private var guideInitialPage = 1
    @State private var saveDocument: PDFFileDocument?
    @State private var saveFilename = "booklet"
    @State private var isSavingPresented = false
    @State private var navigationPath = NavigationPath()

    public init(
        feature: BookletMakerMobileFeature,
        trailingToolbarItems: [AnyView] = []
    ) {
        _feature = StateObject(wrappedValue: feature)
        _workspace = ObservedObject(wrappedValue: feature.workspace)
        self.trailingToolbarItems = trailingToolbarItems
    }

    private var isDocumentPhase: Bool {
        switch workspace.phase {
        case .ready, .generating, .cancelling, .resultReady: true
        case .welcome, .importing, .failed: false
        }
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .regular, isDocumentPhase {
                iPadSplitView
            } else {
                NavigationStack(path: $navigationPath) {
                    content
                        .modifier(TrailingToolbarItemsModifier(items: trailingToolbarItems))
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: feature.selectedTool == .merge
        ) { result in
            guard case .success(let urls) = result, !urls.isEmpty else {
                return // 选择器取消：不改变当前内容
            }
            Task { @MainActor in
                await feature.importDocuments(from: urls)
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
            case .shareMerge(let url):
                SharePresenter.ShareSheet(urls: [url])
                    .presentationDetents([.medium, .large])
            case .saveSplit(let urls):
                SharePresenter.ShareSheet(urls: urls)
                    .presentationDetents([.medium, .large])
            case .saveBooklet(let url), .saveMerge(let url):
                // 单文件：直接进入系统“保存到文件”对话框。
                Color.clear
                    .onAppear {
                        presentSaveExporter(for: url)
                    }
            case .bookletOptions, .splitBatchInput, .splitRename:
                EmptyView()
            }
        }
        .fileExporter(
            isPresented: $isSavingPresented,
            document: saveDocument,
            contentType: .pdf,
            defaultFilename: saveFilename
        ) { _ in
            workspace.present(nil)
        }
        .fullScreenCover(item: $activeGuide) { kind in
            BookletGuideFlowView(
                kind: kind,
                initialPage: guideInitialPage,
                onOpenPDF: {
                    // 多选与否由 `fileImporter` 按当前工具决定，这里只负责
                    // 撤下引导并把系统文件选择器拉起来。
                    dismissGuideThenPresentImporter()
                },
                onUseSample: {
                    prepareTool(for: kind)
                    activeGuide = nil
                    feature.openSampleDocument()
                },
                onDismiss: closeGuideAndReturnHome
            )
        }
        .tint(BookletMobileStyle.accent)
        .onChange(of: workspace.phase) { phase in
            // 进入工作台或回到首页时清空导航栈，避免退回被覆盖的中间页面。
            if phase == .ready || phase == .welcome {
                navigationPath = NavigationPath()
            }
        }
    }

    // MARK: - iPad split view

    /// 宽屏（iPad 常规尺寸类）：侧栏为文档与工具选择，详情为工具页。
    /// 折叠/展开只影响外观，feature 始终唯一，不会复制路径或 VM。
    private var iPadSplitView: some View {
        NavigationSplitView {
            iPadSidebar
                .modifier(TrailingToolbarItemsModifier(items: trailingToolbarItems))
                .navigationTitle(BookletLocalization.string("Booklet Maker"))
                .navigationBarTitleDisplayMode(.inline)
        } detail: {
            NavigationStack {
                feature.makeContentView(onOpenPDF: { isImporterPresented = true })
            }
        }
    }

    private var iPadSidebar: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    PDFDocumentPageView(
                        documentURL: feature.documentPreviewURL,
                        pageNumber: 1
                    )
                    .frame(width: 44, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.documentName)
                            .font(.headline)
                            .lineLimit(2)
                        Text(BookletLocalization.string(
                            "%lld pages",
                            Int64(feature.pageCount)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                toolRow(.booklet)
                toolRow(.split)
                toolRow(.merge)
            }
        }
        .toolbar {
            homeToolbarItem
        }
    }

    // MARK: - Routing

    @ViewBuilder
    private var content: some View {
        Group {
            switch workspace.phase {
            case .welcome, .failed:
                BookletWelcomeView(
                    feature: feature,
                    onChooseTool: startGuide(for:)
                )
            case .importing:
                importingView
            case .ready, .generating, .cancelling, .resultReady:
                // 引导已经选定工具，这里直接进对应工作台，不再经过中间概览页。
                feature.makeContentView(
                    onOpenPDF: { isImporterPresented = true },
                    onReturnToGuide: { showGuide(.booklet, startingAt: 2) }
                )
            }
        }
        // 首页按钮只在工作台阶段出现。
        //
        // 工作台必须自带它：iPhone 上工作台是导航栈的栈顶根页，没有返回
        // 按钮。不给工作台挂首页按钮，用户打开文件后就再也回不到首页，
        // 只能杀进程重启——这是真实的单向故障。
        .toolbar { homeToolbarItem }
    }

    /// 导航栏右侧的「首页」按钮。
    ///
    /// 只有拿到文档（进入工作台）之后才出现：首页自己不需要它，而工作台
    /// 是导航栈的栈顶根页，这个按钮是离开工作台的唯一路径。
    @ToolbarContentBuilder
    private var homeToolbarItem: some ToolbarContent {
        if isDocumentPhase {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    returnToHome()
                } label: {
                    Image(systemName: "house.fill")
                }
                .accessibilityIdentifier("home.button")
                .accessibilityLabel(BookletLocalization.string("Home"))
            }
        }
    }

    /// 从首页点工具卡：记住工具并打开全屏引导。
    private func startGuide(for tool: BookletMakerMobileFeature.Tool) {
        showGuide(BookletGuideKind(tool))
    }

    /// 打开引导，并保证工作台已经准备好对应的工具。
    ///
    /// 引导有两个入口：首页的工具卡，以及帮助页的「再看一次引导」。
    /// 后者不带工具信息，所以这里统一补一次工具选择——否则引导结束时
    /// 打开的文件会落进默认工具的工作台。
    ///
    /// - Parameters:
    ///   - kind: 引导的工具种类。
    ///   - startingAt: 引导从第几屏开始。小册子拼版预览的「上一步」要回到
    ///     第 2 屏（讲解「选择 PDF」那一步），帮助页则从第 1 屏开始。
    private func showGuide(_ kind: BookletGuideKind, startingAt page: Int = 1) {
        prepareTool(for: kind)
        guideInitialPage = page
        activeGuide = kind
    }

    /// 关闭引导并回到首页。
    ///
    /// 引导可能由首页或帮助页打开，关闭时统一丢弃当前文档并清空导航栈，
    /// 避免退回被覆盖的中间页面。
    private func closeGuideAndReturnHome() {
        activeGuide = nil
        returnToHome()
    }

    /// 回到首页：丢弃当前文档并清空导航栈。
    ///
    /// 工具工作台是导航栈的栈顶根页，没有返回按钮；首页按钮是离开工作台
    /// 的唯一路径，因此这里必须把文档一并丢掉——否则首页会显示成「已有
    /// 文档」的工作台状态。
    private func returnToHome() {
        navigationPath = NavigationPath()
        feature.closeDocument()
    }

    private func prepareTool(for kind: BookletGuideKind) {
        let tool: BookletMakerMobileFeature.Tool = switch kind {
        case .booklet: .booklet
        case .split: .split
        case .merge: .merge
        }
        feature.chooseToolForNewDocument(tool)
    }

    /// 先撤下全屏引导再拉起系统文件选择器。
    ///
    /// 两者都是全屏模态，同一帧内换 presentation 会互相打架，
    /// 因此让 cover 的关闭动画先走完再弹出选择器。
    private func dismissGuideThenPresentImporter() {
        activeGuide = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            isImporterPresented = true
        }
    }

    // MARK: - Result & presentation bindings

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

    private func toolRow(_ tool: BookletMakerMobileFeature.Tool) -> some View {
        Button {
            feature.selectedTool = tool
        } label: {
            Label(tool.title, systemImage: tool.systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            feature.selectedTool == tool
                ? Color.accentColor
                : Color.primary
        )
    }

    private var presentationBinding: Binding<MobileWorkspaceState.Presentation?> {
        Binding(
            get: { workspace.presentation },
            set: { workspace.present($0) }
        )
    }

    private func presentSaveExporter(for url: URL) {
        saveDocument = PDFFileDocument(url: url)
        saveFilename = url.deletingPathExtension().lastPathComponent
        isSavingPresented = true
        workspace.present(nil)
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
        .navigationTitle(BookletLocalization.string("Booklet Maker"))
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

/// 把宿主提供的工具栏项挂到当前导航栈的尾部。
///
/// 必须挂在**导航栈内部**的视图上：SwiftUI 的 `.toolbar` 只对最近的导航
/// 容器生效，挂在 `NavigationStack` 外面会被外层上下文接走。
private struct TrailingToolbarItemsModifier: ViewModifier {
    let items: [AnyView]

    @ViewBuilder
    func body(content: Content) -> some View {
        if items.isEmpty {
            content
        } else {
            content.toolbar {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    ToolbarItem(placement: .topBarTrailing) {
                        item
                    }
                }
            }
        }
    }
}
#endif
