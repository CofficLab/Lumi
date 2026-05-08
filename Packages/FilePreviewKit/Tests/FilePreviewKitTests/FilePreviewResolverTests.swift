import Foundation
import Testing
@testable import FilePreviewKit

struct FilePreviewResolverTests {

    @Test
    func resolvesImageExtensions() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.JPEG")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.jpg")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.gif")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.tiff")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.bmp")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.webp")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.heic")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.heif")) == .image)
    }

    @Test
    func resolvesPdfExtensions() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.pdf")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.PDF")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.Pdf")) == .pdf)
    }

    @Test
    func fallsBackToQuickLookForOtherFiles() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.json")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.txt")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.md")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.swift")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.mp4")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.mp3")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.zip")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.doc")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.xls")) == .quickLook)
    }

    @Test
    func handlesEmptyExtension() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/file")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "file")) == .quickLook)
    }

    @Test
    func handlesMixedCaseExtensions() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.PnG")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.JpG")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.PDF")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.pDf")) == .pdf)
    }

    @Test
    func handlesPathsWithDots() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/my.file.name.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/path.with.dots/document.final.pdf")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/.hidden/file.png")) == .image)
    }

    @Test
    func handlesSpecialCharactersInPath() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/file with spaces.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/file-with-dashes.pdf")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/file_with_underscores.jpg")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/文件.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/emoji😀.pdf")) == .pdf)
    }

    @Test
    func handlesAbsoluteAndRelativePaths() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/absolute/path/image.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "relative/path/doc.pdf")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "./current/dir/file.json")) == .quickLook)
    }

    @Test
    func previewKindEquality() {
        #expect(FilePreviewKind.image == FilePreviewKind.image)
        #expect(FilePreviewKind.pdf == FilePreviewKind.pdf)
        #expect(FilePreviewKind.quickLook == FilePreviewKind.quickLook)
        #expect(FilePreviewKind.image != FilePreviewKind.pdf)
        #expect(FilePreviewKind.pdf != FilePreviewKind.quickLook)
        #expect(FilePreviewKind.image != FilePreviewKind.quickLook)
    }

    @Test
    func handlesURLsWithQueryParameters() {
        // URL with query parameters should still work based on path extension
        let url = URL(string: "file:///tmp/image.png?version=1")!
        #expect(FilePreviewResolver.previewKind(for: url) == .image)
    }

    @Test
    func handlesURLsWithFragment() {
        // URL with fragment should still work based on path extension
        let url = URL(string: "file:///tmp/document.pdf#page=5")!
        #expect(FilePreviewResolver.previewKind(for: url) == .pdf)
    }
}
