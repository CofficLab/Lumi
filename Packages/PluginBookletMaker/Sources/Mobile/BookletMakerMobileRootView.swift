#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// BookletMaker 移动端根视图。
///
/// 每个 scene 对应一个移动会话：`@StateObject` 持有 feature（业务 VM +
/// 工作区状态机 + 文件生命周期），系统文件选择器在此统一挂载，避免
/// App 与 Mobile 各嵌一层 NavigationStack。
public struct BookletMakerMobileRootView: View {
    @StateObject public var feature: BookletMakerMobileFeature
    @State private var isImporterPresented = false

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
#endif
