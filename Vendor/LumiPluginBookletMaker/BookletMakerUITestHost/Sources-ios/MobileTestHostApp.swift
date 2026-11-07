import Foundation
import PDFKit
import SwiftUI
import UIKit
import PluginBookletMaker

/// iOS UI 测试宿主入口。
///
/// 与 macOS 宿主的根本差异：iOS 侧不经过 Kernel。插件在 iOS 上以
/// `BookletMakerMobileRootView` 的形态整体呈现——`BookletMakerMobileFeature`
/// 自己持有 ViewModel、工作区状态机与文件生命周期，不向 Rail / ContentView
/// 注册任何内容。因此这里只需构造 feature 并挂载根视图，无需装配 Provider。
///
/// 这也意味着 macOS 宿主里「注册 Provider → 启动插件 → 组装视图」的顺序要求
/// 在 iOS 上不存在，不要照搬。
@main
struct BookletMakerMobileTestHostApp: App {
    @StateObject private var feature = BookletMakerMobileFeature()

    var body: some Scene {
        WindowGroup {
            BookletMakerMobileTestHostRoot(feature: feature)
        }
    }
}

private struct BookletMakerMobileTestHostRoot: View {
    @ObservedObject var feature: BookletMakerMobileFeature

    var body: some View {
        BookletMakerMobileRootView(feature: feature)
            .onAppear {
                // 存储 feature 引用，供测试接缝访问。
                TestHostState.feature = feature
                // 立即注入，不延迟。importDocuments 会自动切换到合并工具。
                injectMergeQueueIfRequested()
            }
    }

    /// 按启动参数注入合并队列测试文件。
    ///
    /// 由界面测试通过 `-SeedMergeQueue 3` 传入。
    private func injectMergeQueueIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-SeedMergeQueue"),
              flagIndex + 1 < arguments.count,
              let count = Int(arguments[flagIndex + 1]),
              count >= 0
        else { return }

        // count == 0 时不注入任何文件，保持空队列。
        guard count > 0 else { return }

        Task { @MainActor in
            do {
                let urls = try MobileTestFixture.makePDFs(count: count)
                await feature.importDocuments(from: urls)
            } catch {
                NSLog("[testhost] 生成合并队列测试文件失败：%@", String(describing: error))
            }
        }
    }
}

/// 全局状态：存储 feature 引用，供测试接缝访问。
@MainActor
enum TestHostState {
    static var feature: BookletMakerMobileFeature?
}

/// 测试接缝：允许测试主动触发合并队列注入。
///
/// 由于 `BookletMakerMobileFeature.selectedTool` 是计算属性，SwiftUI 的
/// `.onChange` 无法监听它的变化。因此测试需要在切换到合并工具后，主动调用
/// `BookletMakerMobileTestHooks.injectMergeQueue()` 来触发注入。
public enum BookletMakerMobileTestHooks {
    /// 检查启动参数并注入合并队列。
    ///
    /// 测试流程：
    /// 1. 启动应用（可传入 `-SeedMergeQueue N` 参数）
    /// 2. 调用 `openSampleDocument()` 打开示例文档
    /// 3. 调用 `switchTool("overview.mergeTool")` 切换到合并工具
    /// 4. 调用 `BookletMakerMobileTestHooks.injectMergeQueue()` 注入队列
    /// 5. 断言合并队列内容
    public static func injectMergeQueue() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-SeedMergeQueue"),
              flagIndex + 1 < arguments.count,
              let count = Int(arguments[flagIndex + 1]),
              count > 0
        else { return }

        // 找到当前的 feature 实例（通过全局访问）。
        // 由于 feature 是 @StateObject，我们需要通过其他方式访问它。
        // 这里使用一个简单的全局变量来存储 feature 引用。
        Task { @MainActor in
            guard let feature = TestHostState.feature else { return }
            do {
                let urls = try MobileTestFixture.makePDFs(count: count)
                await feature.importDocuments(from: urls)
            } catch {
                NSLog("[testhost] 生成合并队列测试文件失败：%@", String(describing: error))
            }
        }
    }
}

/// 生成合并队列的测试用 PDF。
///
/// 用 PDFKit 直接排版而不是手写 PDF 字节：插件自身也用 PDFKit 读这些文件，
/// 两边对「合法 PDF」的理解一致，避免夹具产出的文件插件读不出来。
enum MobileTestFixture {

    /// 生成 `count` 份页数依次为 `1...count` 的临时 PDF。
    ///
    /// 页数刻意各不相同：只有各文件页数可区分，测试才能断言「顺序真的变了」，
    /// 而不是仅凭文件名猜测。
    static func makePDFs(count: Int) throws -> [URL] {
        var urls: [URL] = []
        for pageCount in 1 ... count {
            urls.append(try makePDF(pageCount: pageCount))
        }
        return urls
    }

    private static func makePDF(pageCount: Int) throws -> URL {
        let document = PDFDocument()
        for page in 1 ... max(pageCount, 1) {
            let image = renderPageLabel(page)
            guard let pdfPage = PDFPage(image: image) else {
                throw CocoaError(.fileWriteUnknown)
            }
            document.insert(pdfPage, at: document.pageCount)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("merge-fixture-\(UUID().uuidString).pdf")
        guard document.write(to: url) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    private static func renderPageLabel(_ page: Int) -> UIImage {
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let text = "Merge fixture page \(page)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black,
            ]
            text.draw(
                in: CGRect(x: 20, y: size.height / 2, width: size.width - 40, height: 60),
                withAttributes: attributes
            )
        }
    }
}
