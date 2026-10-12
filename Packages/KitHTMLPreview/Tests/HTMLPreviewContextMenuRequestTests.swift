@testable import KitHTMLPreview
import Foundation
import Testing

@Suite("HTML preview context menu request")
struct HTMLPreviewContextMenuRequestTests {
    @Test("decodes and normalizes a valid request")
    func decodesValidRequest() throws {
        let request = try HTMLPreviewContextMenuRequestDecoder.decode(body: validBody(
            attributes: ["data-block": "hero", "onclick": "secret()"]
        ))

        #expect(request.schemaVersion == 1)
        #expect(request.action == "openContextMenu")
        #expect(request.candidates.count == 1)
        #expect(request.candidates[0].label == "Hero")
        #expect(request.candidates[0].attributes == ["data-block": "hero"])
    }

    @Test("rejects an unsupported schema version")
    func rejectsUnsupportedVersion() {
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(body: validBody(schemaVersion: 2))
        }
    }

    @Test("rejects an unknown action")
    func rejectsUnknownAction() {
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(body: validBody(action: "send"))
        }
    }

    @Test("rejects empty and oversized candidate lists")
    func rejectsCandidateCount() {
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(body: validBody(candidates: []))
        }
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            let candidate = validCandidate()
            try HTMLPreviewContextMenuRequestDecoder.decode(
                body: validBody(candidates: Array(repeating: candidate, count: 6))
            )
        }
    }

    @Test("rejects invalid coordinates")
    func rejectsInvalidCoordinates() {
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(body: validBody(clientX: 200_000))
        }
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(body: validBody(clientY: Double.nan))
        }
    }

    @Test("rejects oversized selectors labels and HTML")
    func rejectsOversizedFields() {
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(
                body: validBody(candidates: [validCandidate(selector: String(repeating: "x", count: 2_049))])
            )
        }
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(
                body: validBody(candidates: [validCandidate(label: String(repeating: "x", count: 257))])
            )
        }
        #expect(throws: HTMLPreviewContextMenuRequestError.self) {
            try HTMLPreviewContextMenuRequestDecoder.decode(
                body: validBody(candidates: [validCandidate(
                    outerHTML: String(repeating: "x", count: 24 * 1_024 + 1),
                    isOuterHTMLTruncated: true
                )])
            )
        }
    }

    @Test("removes control characters from labels")
    func normalizesControlCharacters() throws {
        let request = try HTMLPreviewContextMenuRequestDecoder.decode(
            body: validBody(candidates: [validCandidate(label: "  Hero\u{0000}\n title  ")])
        )

        #expect(request.candidates[0].label == "Hero title")
    }

    private func validBody(
        schemaVersion: Int = 1,
        action: String = "openContextMenu",
        clientX: Double = 20,
        clientY: Double = 30,
        attributes: [String: String] = ["data-block": "hero"],
        candidates: [[String: Any]]? = nil
    ) -> [String: Any] {
        [
            "schemaVersion": schemaVersion,
            "action": action,
            "requestID": "request-1",
            "navigationGeneration": 4,
            "clientX": clientX,
            "clientY": clientY,
            "candidates": candidates ?? [validCandidate(attributes: attributes)],
        ]
    }

    private func validCandidate(
        selector: String = #"[data-block="hero"]"#,
        label: String = "Hero",
        outerHTML: String = #"<section data-block="hero">Hello</section>"#,
        isOuterHTMLTruncated: Bool = false,
        attributes: [String: String] = ["data-block": "hero"]
    ) -> [String: Any] {
        [
            "schemaVersion": 1,
            "selector": selector,
            "tagName": "section",
            "label": label,
            "textPreview": "Hello",
            "outerHTML": outerHTML,
            "isOuterHTMLTruncated": isOuterHTMLTruncated,
            "blockID": "hero",
            "blockLabel": "Hero",
            "attributes": attributes,
        ]
    }
}
