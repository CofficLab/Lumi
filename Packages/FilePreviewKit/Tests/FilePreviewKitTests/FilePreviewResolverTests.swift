import Foundation
import Testing
@testable import FilePreviewKit

@Suite("FilePreviewResolver")
struct FilePreviewResolverTests {
    @Test("Image filename extensions use image preview")
    func imageExtensionsUseImagePreview() {
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/photo.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/photo.JPG")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/photo.heic")) == .image)
    }

    @Test("PDF extensions use PDF preview")
    func pdfExtensionsUsePDFPreview() {
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/document.pdf")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/document.PDF")) == .pdf)
    }

    @Test("Unknown or missing extensions fall back to Quick Look")
    func unknownExtensionsUseQuickLookPreview() {
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/readme.txt")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(fileURLWithPath: "/tmp/Makefile")) == .quickLook)
    }
}
