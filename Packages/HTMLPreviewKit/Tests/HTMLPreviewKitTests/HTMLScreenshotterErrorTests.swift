import HTMLPreviewKit
import Testing

@Suite("HTMLScreenshotter errors")
struct HTMLScreenshotterErrorTests {

    @Test("error descriptions are stable and user-readable")
    func errorDescriptions() {
        #expect(HTMLScreenshotter.HTMLError.pdfCreationFailed.errorDescription == "Failed to create PDF from HTML content")
        #expect(HTMLScreenshotter.HTMLError.emptyDocument.errorDescription == "PDF document is empty")
        #expect(HTMLScreenshotter.HTMLError.renderingFailed("No context").errorDescription == "Rendering failed: No context")
    }
}
