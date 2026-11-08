import AppKit
import Foundation
import Testing
@testable import ImageToPDFPlugin

@Suite("Image-to-PDF view model")
@MainActor
struct ImageToPDFViewModelTests {
    @Test("accepts unique image URLs and supports removing and clearing inputs")
    func managesImageInputs() {
        let model = ImageToPDFViewModel()
        let png = URL(fileURLWithPath: "/tmp/first.png")
        let jpeg = URL(fileURLWithPath: "/tmp/second.JPG")
        let pdf = URL(fileURLWithPath: "/tmp/already.pdf")

        let added = model.addImages(from: [png, jpeg, pdf, png])

        #expect(added == 2)
        #expect(model.inputImages.map(\.url) == [png, jpeg])
        #expect(model.inputImages.map(\.suggestedPDFName) == ["first.pdf", "second.pdf"])

        let firstImage = try! #require(model.inputImages.first)
        model.removeImage(firstImage)
        #expect(model.inputImages.map(\.url) == [jpeg])
        model.removeImage(firstImage)
        #expect(model.inputImages.map(\.url) == [jpeg])

        model.clearAll()
        #expect(model.inputImages.isEmpty)
        #expect(model.outputItems.isEmpty)
        #expect(model.lastErrorMessage == nil)
    }

    @Test("invalid image input ends conversion without creating a PDF")
    func rejectsUnreadableImage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sourceURL = root.appendingPathComponent("broken.png")
        let outputURL = root.appendingPathComponent("broken.pdf")
        try Data("not an image".utf8).write(to: sourceURL)
        let source = ImageItem(url: sourceURL)

        var progress: [Double] = []
        for await value in ImageToPDFService().convert(source: source, to: outputURL) {
            progress.append(value)
        }

        #expect(progress == [0.1])
        #expect(FileManager.default.fileExists(atPath: outputURL.path) == false)
    }

    @Test("collects URLs safely when file-provider callbacks arrive concurrently")
    func collectsConcurrentDropResults() {
        let collection = FileURLCollection()
        let urls = (0..<500).map { URL(fileURLWithPath: "/tmp/drop-\($0).png") }

        DispatchQueue.concurrentPerform(iterations: urls.count) { index in
            collection.append(urls[index])
        }

        let collected = collection.snapshot()
        #expect(collected.count == urls.count)
        #expect(Set(collected) == Set(urls))
    }

    @Test("同名不同目录的图片生成独立 PDF，导出不互相覆盖")
    func duplicateFileNamesProduceDistinctPDFs() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let png = try #require(Self.onePixelPNGData)
        let directoryA = root.appendingPathComponent("a", isDirectory: true)
        let directoryB = root.appendingPathComponent("b", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: directoryB, withIntermediateDirectories: true)
        let photoA = directoryA.appendingPathComponent("photo.png")
        let photoB = directoryB.appendingPathComponent("photo.png")
        try png.write(to: photoA)
        try png.write(to: photoB)

        let staging = root.appendingPathComponent("staging", isDirectory: true)
        ImageToPDFRuntimeBridge.directoryURL = staging
        defer { ImageToPDFRuntimeBridge.directoryURL = nil }

        let model = ImageToPDFViewModel()
        model.addImages(from: [photoA, photoB])
        #expect(model.inputImages.count == 2)

        model.convertAll()
        while model.isConverting {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let outputURLs = model.outputItems.compactMap { $0.status.outputURL }
        #expect(outputURLs.count == 2)
        #expect(Set(outputURLs.map(\.lastPathComponent)).count == 2)

        let exportDirectory = root.appendingPathComponent("export", isDirectory: true)
        let written = model.exportAll(to: exportDirectory)
        #expect(written == 2)
        let exported = try FileManager.default
            .contentsOfDirectory(atPath: exportDirectory.path)
            .filter { $0.hasSuffix(".pdf") }
        #expect(exported.count == 2)
    }

    /// 1×1 PNG，足够让 `NSImage` 解码并产生一页 PDF。
    private static let onePixelPNGData = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )
}
