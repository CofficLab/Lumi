@testable import KitHTMLPreview
import Testing

@MainActor
@Suite("HTML preview legacy compatibility")
struct HTMLPreviewLegacyCompatibilityTests {
    @Test("legacy block callback remains independent from element references")
    func legacyInitializerRemainsAvailable() {
        let view = HTMLPreviewView(
            htmlText: "<html></html>",
            onBlockSelected: { _ in }
        )

        #expect(view.onBlockSelected != nil)
        #expect(view.onElementReferenceSelected == nil)
    }

    @Test("legacy message decoding preserves defaults")
    func legacyMessageDecoding() {
        let selection = PromoBlockSelection.decodeLegacyMessageBody([
            "action": "send",
            "blockID": "hero",
            "outerHTML": "<section></section>",
        ])
        let defaults = PromoBlockSelection.decodeLegacyMessageBody(["action": "send"])

        #expect(selection == PromoBlockSelection(
            blockID: "hero",
            label: "hero",
            outerHTML: "<section></section>"
        ))
        #expect(defaults == PromoBlockSelection(blockID: "block", label: "block", outerHTML: ""))
        #expect(PromoBlockSelection.decodeLegacyMessageBody(["action": "other"]) == nil)
    }

    @Test("new element callback does not enable the legacy bridge")
    func newInitializerKeepsLegacyDisabled() {
        let view = HTMLPreviewView(
            htmlText: "<html></html>",
            onElementReferenceSelected: { _ in }
        )

        #expect(view.onBlockSelected == nil)
        #expect(view.onElementReferenceSelected != nil)
    }
}
