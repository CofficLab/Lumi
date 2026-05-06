import Foundation
import Testing
@testable import FilePreviewKit

struct FilePreviewResolverTests {

    @Test
    func resolvesImageExtensions() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.png")) == .image)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.JPEG")) == .image)
    }

    @Test
    func resolvesPdfExtensions() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.pdf")) == .pdf)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.PDF")) == .pdf)
    }

    @Test
    func fallsBackToQuickLookForOtherFiles() {
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo.json")) == .quickLook)
        #expect(FilePreviewResolver.previewKind(for: URL(filePath: "/tmp/demo")) == .quickLook)
    }
}
