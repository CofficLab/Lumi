import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - View Model

/// State container for the Image-to-PDF converter screen.
///
/// Owns the user's input image list, the per-file PDF output list, and
/// orchestrates the conversion and export pipelines. All mutations happen
/// on the main actor so SwiftUI bindings stay consistent.
@MainActor
final class ImageToPDFViewModel: ObservableObject {
    // MARK: - Inputs

    /// Images the user has dropped / picked but yet converted.
    @Published private(set) var inputImages: [ImageItem] = []

    /// PDFs produced by the most recent conversion run.
    @Published private(set) var outputItems: [PDFOutputItem] = []

    /// True while a `convertAll` is running.
    @Published private(set) var isConverting: Bool = false

    /// 只要还有未清空的输入或输出，Clear 就应可用。
    ///
    /// `clearAll()` 同时清空三者，所以按钮可用性不能只看 `outputItems`：
    /// 用户只添加了图片、还没转换时也必须能一键清空。
    var canClear: Bool {
        !inputImages.isEmpty || !outputItems.isEmpty
    }

    /// Human-readable message from the most recent failure, or nil.
    @Published private(set) var lastErrorMessage: String?

    // MARK: - Dependencies

    private let service: any ImageToPDFConverting

    /// 转换回合代号：每次开始转换递增，Clear 也递增。Task 内所有写回前比对代号，
    /// 旧回合的迟到进度/状态/完成态一律拒绝，不得把已清空的列表重新填回（#380）。
    private var conversionGeneration = 0
    private var conversionTask: Task<Void, Never>?

    // MARK: Init

    init(service: any ImageToPDFConverting = ImageToPDFService()) {
        self.service = service
    }

    // MARK: - Input Management

    /// Append files dragged into the drop zone. Filters to image files only
    /// and de-duplicates against the existing input list.
    ///
    /// - Parameter urls: URLs received from `NSItemProvider`.
    /// - Returns: Count of files actually added.
    @discardableResult
    func addImages(from urls: [URL]) -> Int {
        var added = 0
        for url in urls {
            guard ImageItem.isAccepted(url: url) else { continue }
            if inputImages.contains(where: { $0.url == url }) { continue }
            inputImages.append(ImageItem(url: url))
            added += 1
        }
        return added
    }

    /// Remove an image from the input list.
    func removeImage(_ item: ImageItem) {
        inputImages.removeAll { $0.id == item.id }
    }

    /// Open a file picker and add the selected image files.
    func pickImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK {
            addImages(from: panel.urls)
        }
    }

    /// Clear every input image and every output PDF.
    ///
    /// 转换进行中 Clear 必须作废旧回合：递增代号拒绝其迟到写回，并取消底层 Task，
    /// 否则旧 Task 持有的 `runningItems` 会把已清空的输入/输出整批填回（#380）。
    func clearAll() {
        conversionGeneration += 1
        conversionTask?.cancel()
        conversionTask = nil
        isConverting = false
        inputImages.removeAll()
        outputItems.removeAll()
        lastErrorMessage = nil
    }

    // MARK: - Conversion

    /// Convert every input image to a PDF in a temporary in-memory directory.
    ///
    /// PDFs are written to a staging directory inside the user's `Caches`
    /// folder and exposed via `outputItems` so the user can preview them
    /// before exporting to a final location.
    func convertAll() {
        guard !isConverting else { return }
        guard !inputImages.isEmpty else { return }

        let stagingDirectory = makeStagingDirectory()
        let images = inputImages
        let names = Self.uniquePDFNames(for: images)
        outputItems = zip(images, names).map { PDFOutputItem(source: $0, outputName: $1) }
        isConverting = true
        lastErrorMessage = nil
        conversionGeneration += 1
        let generation = conversionGeneration

        conversionTask = Task {
            var runningItems = outputItems

            for index in runningItems.indices {
                guard generation == conversionGeneration else { return }
                runningItems[index].status = .processing
                runningItems[index].progress = 0
                outputItems = runningItems

                let item = runningItems[index]
                let outputURL = stagingDirectory.appendingPathComponent(item.outputName)

                let stream = service.convert(source: item.source, to: outputURL)
                do {
                    for try await value in stream {
                        guard generation == conversionGeneration else { return }
                        runningItems[index].progress = value
                        outputItems = runningItems
                    }

                    guard generation == conversionGeneration else { return }
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        runningItems[index].status = .done(outputURL)
                        runningItems[index].progress = 1
                    } else {
                        runningItems[index].status = .failed(
                            ImageToPDFLocalization.string("Unknown error")
                        )
                    }
                } catch {
                    guard generation == conversionGeneration else { return }
                    // 失败时清掉可能残留的旧目标，避免用户导出上一轮的内容。
                    try? FileManager.default.removeItem(at: outputURL)
                    runningItems[index].status = .failed(error.localizedDescription)
                }
                guard generation == conversionGeneration else { return }
                outputItems = runningItems
            }

            guard generation == conversionGeneration else { return }
            isConverting = false

            let failureCount = outputItems.filter {
                if case .failed = $0.status { return true }
                return false
            }.count
            if failureCount > 0 {
                guard generation == conversionGeneration else { return }
                lastErrorMessage = String(
                    format: ImageToPDFLocalization.string("%ld file(s) failed to convert"),
                    failureCount
                )
            }
        }
    }

    // MARK: - Export

    /// Export every successfully converted PDF to `directoryURL`.
    ///
    /// Returns the number of files actually written. Failed exports are
    /// surfaced through `lastErrorMessage`.
    @discardableResult
    func exportAll(to directoryURL: URL) async -> Int {
        // 主线程只做快照：收集已成功输出的源文件 URL（Sendable）。
        // 目录准备与逐文件复制随输出数量与总字节增长，移到后台线程（#1197）。
        let sources: [URL] = outputItems.compactMap { item in
            if case .done(let url) = item.status { return url }
            return nil
        }

        let result = await Task.detached(priority: .userInitiated) {
            Self.copyOutputs(sources, to: directoryURL)
        }.value

        if !result.failed.isEmpty {
            lastErrorMessage = String(
                format: ImageToPDFLocalization.string("Could not export: %@"),
                result.failed.joined(separator: ", ")
            )
        } else {
            lastErrorMessage = nil
        }

        return result.written
    }

    /// 在后台线程把源 PDF 复制到目标目录，保留「同名目录拒绝、先临时文件再原子
    /// 替换、失败不破坏旧结果」的既有行为。返回写入数与失败文件名。
    nonisolated static func copyOutputs(
        _ sources: [URL],
        to directoryURL: URL
    ) -> (written: Int, failed: [String]) {
        var written = 0
        var failed: [String] = []

        for existingURL in sources {
            let destination = directoryURL.appendingPathComponent(
                existingURL.lastPathComponent
            )
            let tempURL = directoryURL.appendingPathComponent(
                ".export-\(UUID().uuidString).tmp"
            )

            do {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )

                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(
                    atPath: destination.path,
                    isDirectory: &isDirectory
                )
                // 目标是同名目录时拒绝导出并保留其内容，绝不递归删除。
                if exists && isDirectory.boolValue {
                    failed.append(existingURL.lastPathComponent)
                    continue
                }

                // 先复制到临时文件再原子替换，复制失败时不破坏已存在的旧结果。
                try FileManager.default.copyItem(at: existingURL, to: tempURL)
                if exists {
                    _ = try FileManager.default.replaceItemAt(destination, withItemAt: tempURL)
                } else {
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                }
                written += 1
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                failed.append(existingURL.lastPathComponent)
            }
        }

        return (written, failed)
    }

    /// Open a directory picker, then export every converted PDF there.
    func chooseDirectoryAndExport() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = ImageToPDFLocalization.string("Export")
        panel.message = ImageToPDFLocalization.string(
            "Choose a folder to export the PDFs into"
        )

        guard panel.runModal() == .OK, let directory = panel.url else { return }

        await exportAll(to: directory)
    }

    /// Show the produced PDF in Finder.
    func revealInFinder(_ item: PDFOutputItem) {
        guard let url = item.status.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open the produced PDF in Preview.app.
    func openInPreview(_ item: PDFOutputItem) {
        guard let url = item.status.outputURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Remove a single output item from the list (does not delete the PDF on disk).
    func removeOutput(_ item: PDFOutputItem) {
        outputItems.removeAll { $0.id == item.id }
    }

    // MARK: - Private

    /// 为一批输入分配互不冲突的 PDF 文件名：重名时追加 ` (2)`、` (3)`…
    ///
    /// 输入只按 URL 去重，来自不同目录的同名图片可以同时存在；如果直接用
    /// `suggestedPDFName`，它们会写同一个暂存文件，后一张覆盖前一张。
    static func uniquePDFNames(for images: [ImageItem]) -> [String] {
        var used: Set<String> = []
        return images.map { image in
            let base = image.suggestedPDFName
            let stem = (base as NSString).deletingPathExtension
            var candidate = base
            var suffix = 2
            while used.contains(candidate.lowercased()) {
                candidate = "\(stem) (\(suffix)).pdf"
                suffix += 1
            }
            used.insert(candidate.lowercased())
            return candidate
        }
    }

    /// Create (or reuse) a per-session staging directory.
    ///
    /// Prefers the directory provided by `ImageToPDFRuntimeBridge`, which
    /// `ImageToPDFPlugin.onBoot` populates from
    /// `kernel.storage?.pluginDataDirectory(for: "ImageToPDF")`. When the
    /// bridge is unavailable (e.g. in unit tests or boot-time UI), it
    /// falls back to a unique temporary folder so conversions still work.
    private func makeStagingDirectory() -> URL {
        let fm = FileManager.default
        let base = ImageToPDFRuntimeBridge.directoryURL
            ?? fm.temporaryDirectory.appendingPathComponent("ImageToPDFPlugin", isDirectory: true)

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
