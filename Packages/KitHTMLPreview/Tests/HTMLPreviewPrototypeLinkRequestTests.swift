import Foundation
import Testing

@testable import KitHTMLPreview

@Suite("HTML preview prototype link request")
struct HTMLPreviewPrototypeLinkRequestTests {

    @Test("decodes a valid request and preserves the navigation generation")
    func decodesValidRequest() throws {
        let request = try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
            "schemaVersion": 1,
            "action": "prototypeLink",
            "navigationGeneration": 3,
            "target": "02-detail",
        ])

        #expect(request == HTMLPreviewPrototypeLinkRequest(
            schemaVersion: 1,
            action: "prototypeLink",
            navigationGeneration: 3,
            target: "02-detail"
        ))
    }

    @Test("trims surrounding whitespace from the target")
    func trimsTarget() throws {
        let request = try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
            "schemaVersion": 1,
            "action": "prototypeLink",
            "navigationGeneration": 0,
            "target": "  02-detail  ",
        ])

        #expect(request.target == "02-detail")
    }

    @Test("rejects an unsupported schema version")
    func rejectsUnsupportedVersion() {
        #expect(throws: HTMLPreviewPrototypeLinkRequestError.unsupportedSchemaVersion) {
            try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
                "schemaVersion": 2,
                "action": "prototypeLink",
                "navigationGeneration": 0,
                "target": "02-detail",
            ])
        }
    }

    @Test("rejects an unknown action")
    func rejectsUnknownAction() {
        #expect(throws: HTMLPreviewPrototypeLinkRequestError.invalidAction) {
            try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
                "schemaVersion": 1,
                "action": "openContextMenu",
                "navigationGeneration": 0,
                "target": "02-detail",
            ])
        }
    }

    @Test("rejects blank targets")
    func rejectsBlankTarget() {
        for blank in ["", "   ", "\n\t"] {
            #expect(throws: HTMLPreviewPrototypeLinkRequestError.invalidTarget) {
                try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
                    "schemaVersion": 1,
                    "action": "prototypeLink",
                    "navigationGeneration": 0,
                    "target": blank,
                ])
            }
        }
    }

    @Test("rejects oversized targets")
    func rejectsOversizedTarget() {
        #expect(throws: HTMLPreviewPrototypeLinkRequestError.invalidTarget) {
            try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
                "schemaVersion": 1,
                "action": "prototypeLink",
                "navigationGeneration": 0,
                "target": String(repeating: "a", count: 257),
            ])
        }
    }

    @Test("rejects oversized payloads")
    func rejectsPayloadTooLarge() {
        #expect(throws: HTMLPreviewPrototypeLinkRequestError.payloadTooLarge) {
            try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: [
                "schemaVersion": 1,
                "action": "prototypeLink",
                "navigationGeneration": 0,
                "target": String(repeating: "a", count: 5_000),
            ])
        }
    }

    @Test("rejects non-object bodies")
    func rejectsInvalidJSON() {
        #expect(throws: HTMLPreviewPrototypeLinkRequestError.invalidJSON) {
            try HTMLPreviewPrototypeLinkRequestDecoder.decode(body: "not-a-dictionary")
        }
    }
}
