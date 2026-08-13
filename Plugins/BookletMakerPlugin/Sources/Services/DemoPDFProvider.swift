import CoreGraphics
import CoreText
import Foundation

#if canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#endif

private func platformFont(size: CGFloat, weight: PlatformFont.Weight = .regular) -> PlatformFont {
    PlatformFont.systemFont(ofSize: size, weight: weight)
}

private func platformGray(white: CGFloat, alpha: CGFloat = 1) -> PlatformColor {
    #if canImport(AppKit)
    return PlatformColor(calibratedWhite: white, alpha: alpha)
    #elseif canImport(UIKit)
    return PlatformColor(white: white, alpha: alpha)
    #endif
}

/// Creates the built-in demonstration as a real PDF document.
///
/// Keeping the sample on disk means it travels through exactly the same
/// CGPDF/PDFKit preview and export pipeline as a user-selected file.
enum DemoPDFProvider {
    private static let pageSize = CGSize(width: 595, height: 842)

    static func makeDocument() throws -> CurrentPDFDocument {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookletMakerDemo", isDirectory: true)
        // Keep the version in the filename so an already-running development
        // build never reuses a demo generated with older drawing rules.
        let url = directory.appendingPathComponent("sample-story-v2.pdf")

        if !isValidDemo(at: url) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try makePDFData().write(to: url, options: .atomic)
        }

        return CurrentPDFDocument(
            source: .demo,
            url: url,
            info: PDFInspector.PDFInfo(
                pageCount: SampleStory.pageCount,
                firstPageSize: pageSize
            )
        )
    }

    private static func isValidDemo(at url: URL) -> Bool {
        guard let document = CGPDFDocument(url as CFURL) else { return false }
        return document.numberOfPages == SampleStory.pageCount
    }

    private static func makePDFData() throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        for storyPage in SampleStory.pages {
            context.beginPDFPage(nil)
            draw(storyPage, in: mediaBox, context: context)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    private static func draw(_ page: SampleStory.Page,
                             in bounds: CGRect,
                             context: CGContext) {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(bounds)

        drawText(
            page.icon,
            in: CGRect(x: 60, y: 650, width: bounds.width - 120, height: 90),
            font: platformFont(size: 64),
            color: .black,
            alignment: .center,
            context: context
        )
        drawText(
            page.title,
            in: CGRect(x: 55, y: 555, width: bounds.width - 110, height: 70),
            font: platformFont(size: 28, weight: .semibold),
            color: .black,
            alignment: .center,
            context: context
        )
        drawText(
            page.body,
            in: CGRect(x: 70, y: 220, width: bounds.width - 140, height: 300),
            font: platformFont(size: 20),
            color: platformGray(white: 0.28),
            alignment: .center,
            lineSpacing: 8,
            context: context
        )
        drawText(
            String(page.id),
            in: CGRect(x: 18, y: 14, width: 60, height: 36),
            font: platformFont(size: 20, weight: .medium),
            color: platformGray(white: 0.42),
            alignment: .left,
            context: context
        )
    }

    private static func drawText(_ text: String,
                                 in rect: CGRect,
                                 font: PlatformFont,
                                 color: PlatformColor,
                                 alignment: NSTextAlignment,
                                 lineSpacing: CGFloat = 0,
                                 context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )
        context.saveGState()
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        context.restoreGState()
    }
}
