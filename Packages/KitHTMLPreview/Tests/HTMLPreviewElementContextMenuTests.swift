@testable import KitHTMLPreview
import Foundation
import Testing

@Suite("HTML preview element context menu")
struct HTMLPreviewElementContextMenuTests {
    @Test("orders the target before its ancestors")
    func ordersCandidates() {
        let items = HTMLPreviewElementContextMenuModel.items(
            candidates: [reference(label: "Checkout", tag: "button"), reference(label: "Actions", tag: "section")],
            isEnabled: true,
            locale: Locale(identifier: "en"),
            localize: { $0 }
        )

        #expect(items.map(\.reference.label) == ["Checkout", "Actions"])
        #expect(items[0].title == "Send “Checkout” to Conversation")
        #expect(items[1].title == "Send Parent “Actions” to Conversation")
    }

    @Test("distinguishes repeated labels")
    func distinguishesRepeatedLabels() {
        let items = HTMLPreviewElementContextMenuModel.items(
            candidates: [reference(label: "Item", tag: "button"), reference(label: "Item", tag: "section", blockID: "card")],
            isEnabled: true,
            locale: Locale(identifier: "en"),
            localize: { $0 }
        )

        #expect(items[0].title.contains("button"))
        #expect(items[1].title.contains("card"))
    }

    @Test("truncates titles by user-perceived characters")
    func truncatesLabels() {
        let label = String(repeating: "👨‍👩‍👧‍👦", count: 60)
        let item = HTMLPreviewElementContextMenuModel.items(
            candidates: [reference(label: label, tag: "div")],
            isEnabled: true,
            locale: Locale(identifier: "en"),
            localize: { $0 }
        )[0]

        #expect(item.displayLabel.count == 48)
        #expect(item.displayLabel.hasSuffix("…"))
    }

    @Test("disables every action when conversation is unavailable")
    func disablesUnavailableActions() {
        let items = HTMLPreviewElementContextMenuModel.items(
            candidates: [reference(label: "Hero", tag: "section")],
            isEnabled: false,
            locale: Locale(identifier: "en"),
            localize: { $0 }
        )

        #expect(items.count == 1)
        #expect(items[0].isEnabled == false)
        #expect(items[0].title == "Conversation Unavailable")
    }

    private func reference(label: String, tag: String, blockID: String? = nil) -> HTMLPreviewElementReference {
        HTMLPreviewElementReference(
            selector: tag,
            tagName: tag,
            label: label,
            outerHTML: "<\(tag)>\(label)</\(tag)>",
            blockID: blockID
        )
    }
}
