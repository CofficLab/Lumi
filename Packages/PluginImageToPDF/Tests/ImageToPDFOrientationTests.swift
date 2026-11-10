import AppKit
import Foundation
import PDFKit
import Testing
@testable import ImageToPDFPlugin

/// 回归 #758：图片转 PDF 后不得上下镜像。
@Suite("Image-to-PDF orientation")
@MainActor
struct ImageToPDFOrientationTests {

    @Test("PDF 上下方向与源图一致，不产生垂直镜像")
    func preservesVerticalOrientation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageToPDFOrientation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let pngURL = directory.appendingPathComponent("split.png")
        try makeTopRedBottomBluePNG(at: pngURL)
        let pdfURL = directory.appendingPathComponent("split.pdf")

        let service = ImageToPDFService()
        for try await _ in service.convert(source: ImageItem(url: pngURL), to: pdfURL) {}

        let page = try #require(PDFDocument(url: pdfURL)?.page(at: 0))
        let thumbnail = page.thumbnail(of: NSSize(width: 80, height: 80), for: .mediaBox)
        let rep = try #require(thumbnail.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))

        // NSBitmapImageRep.colorAt 以左上角为原点：y=8 是画面顶部，y=71 是底部。
        let top = try #require(rep.colorAt(x: 40, y: 8))
        let bottom = try #require(rep.colorAt(x: 40, y: 71))

        #expect(top.redComponent > 0.6, "PDF 顶部应为源图顶部的红色，实际 \(top)")
        #expect(top.blueComponent < 0.4, "PDF 顶部不应出现源图底部的蓝色，实际 \(top)")
        #expect(bottom.blueComponent > 0.6, "PDF 底部应为源图底部的蓝色，实际 \(bottom)")
        #expect(bottom.redComponent < 0.4, "PDF 底部不应出现源图顶部的红色，实际 \(bottom)")
    }

    /// 生成一张上半红、下半蓝的 80×80 PNG。
    private func makeTopRedBottomBluePNG(at url: URL) throws {
        let context = try #require(
            CGContext(
                data: nil,
                width: 80,
                height: 80,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        // CGContext 原点在左下：先画下半部蓝色，再画上半部红色。
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        context.setFillColor(CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1))
        context.fill(CGRect(x: 0, y: 40, width: 80, height: 40))

        let cgImage = try #require(context.makeImage())
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try data.write(to: url)
    }
}
