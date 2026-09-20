import Foundation
import KitHTMLPreview
import Testing
@testable import PluginPrototypeDesigner

@Suite("Prototype element conversation draft")
struct PrototypeElementConversationDraftBuilderTests {
    @Test("includes precise prototype and element context")
    func includesContext() throws {
        let draft = try PrototypeElementConversationDraftBuilder.draft(
            reference: reference(),
            context: context(),
            localize: { $0 }
        )

        #expect(draft.contains("Checkout (checkout-flow)"))
        #expect(draft.contains("Home (01-home)"))
        #expect(draft.contains("iPhone 15 Pro"))
        #expect(draft.contains(".lumi/prototype/tasks/checkout-flow/01-home/index.html"))
        #expect(draft.contains(#"button[data-block="primary-action"]"#))
        #expect(draft.contains("primary-action (Primary Action)"))
        #expect(draft.contains("<button data-block=\"primary-action\">Pay</button>"))
    }

    @Test("omits absent block metadata cleanly")
    func omitsMissingBlock() throws {
        let draft = try PrototypeElementConversationDraftBuilder.draft(
            reference: reference(blockID: nil, blockLabel: nil),
            context: context(),
            localize: { $0 }
        )

        #expect(!draft.contains("\n- Block:"))
    }

    @Test("does not expose paths outside the project")
    func sanitizesExternalPath() throws {
        var external = context()
        external.sourceURL = URL(fileURLWithPath: "/Users/private/secret/index.html")

        let draft = try PrototypeElementConversationDraftBuilder.draft(
            reference: reference(),
            context: external,
            localize: { $0 }
        )

        #expect(draft.contains("- File: index.html"))
        #expect(!draft.contains("/Users/private"))
    }

    @Test("uses a fence longer than HTML backtick runs")
    func usesSafeMarkdownFence() throws {
        let draft = try PrototypeElementConversationDraftBuilder.draft(
            reference: reference(outerHTML: "<div>```code```</div>"),
            context: context(),
            localize: { $0 }
        )

        #expect(draft.contains("````html"))
        #expect(draft.contains("\n````"))
    }

    @Test("marks truncated references as requiring a fresh read")
    func warnsForTruncatedHTML() throws {
        let draft = try PrototypeElementConversationDraftBuilder.draft(
            reference: reference(isTruncated: true),
            context: context(),
            localize: { $0 }
        )

        #expect(draft.contains("Captured HTML is truncated; read the current screen HTML before editing."))
    }

    @Test("appends after existing composer text")
    func appendsDraft() {
        #expect(PrototypeElementConversationDraftBuilder.appending("Reference", to: "") == "Reference")
        #expect(PrototypeElementConversationDraftBuilder.appending("Reference", to: "My request\n") == "My request\n\nReference")
    }

    @Test("rejects oversized final drafts")
    func rejectsOversizedDraft() {
        #expect(throws: PrototypeElementConversationDraftError.self) {
            _ = try PrototypeElementConversationDraftBuilder.draft(
                reference: reference(outerHTML: String(repeating: "界", count: 20_000)),
                context: context(),
                localize: { $0 }
            )
        }
    }

    private func context() -> PrototypeElementConversationContext {
        PrototypeElementConversationContext(
            projectTitle: "Checkout",
            projectID: "checkout-flow",
            screenTitle: "Home",
            screenID: "01-home",
            deviceName: "iPhone 15 Pro",
            sourceURL: URL(fileURLWithPath: "/workspace/.lumi/prototype/tasks/checkout-flow/01-home/index.html"),
            projectRootPath: "/workspace"
        )
    }

    private func reference(
        outerHTML: String = "<button data-block=\"primary-action\">Pay</button>",
        isTruncated: Bool = false,
        blockID: String? = "primary-action",
        blockLabel: String? = "Primary Action"
    ) -> HTMLPreviewElementReference {
        HTMLPreviewElementReference(
            selector: #"button[data-block="primary-action"]"#,
            tagName: "button",
            label: "Pay",
            textPreview: "Pay",
            outerHTML: outerHTML,
            isOuterHTMLTruncated: isTruncated,
            blockID: blockID,
            blockLabel: blockLabel,
            attributes: ["data-block": "primary-action"]
        )
    }
}
