import Foundation

/// `data-prototype-link` 点击回传消息（issue #323）。
struct HTMLPreviewPrototypeLinkRequest: Decodable, Equatable {
    let schemaVersion: Int
    let action: String
    let navigationGeneration: Int
    let target: String
}

enum HTMLPreviewPrototypeLinkRequestError: Error, Equatable {
    case invalidJSON
    case payloadTooLarge
    case unsupportedSchemaVersion
    case invalidAction
    case invalidTarget
}

enum HTMLPreviewPrototypeLinkRequestDecoder {
    static let maximumPayloadBytes = 4 * 1_024
    static let maximumTargetCharacters = 256

    static func decode(body: Any) throws -> HTMLPreviewPrototypeLinkRequest {
        guard JSONSerialization.isValidJSONObject(body) else {
            throw HTMLPreviewPrototypeLinkRequestError.invalidJSON
        }

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw HTMLPreviewPrototypeLinkRequestError.invalidJSON
        }
        guard data.count <= maximumPayloadBytes else {
            throw HTMLPreviewPrototypeLinkRequestError.payloadTooLarge
        }

        let raw: HTMLPreviewPrototypeLinkRequest
        do {
            raw = try JSONDecoder().decode(HTMLPreviewPrototypeLinkRequest.self, from: data)
        } catch {
            throw HTMLPreviewPrototypeLinkRequestError.invalidJSON
        }

        guard raw.schemaVersion == HTMLPreviewElementReference.currentSchemaVersion else {
            throw HTMLPreviewPrototypeLinkRequestError.unsupportedSchemaVersion
        }
        guard raw.action == "prototypeLink" else {
            throw HTMLPreviewPrototypeLinkRequestError.invalidAction
        }
        let target = raw.target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, target.count <= maximumTargetCharacters else {
            throw HTMLPreviewPrototypeLinkRequestError.invalidTarget
        }
        return HTMLPreviewPrototypeLinkRequest(
            schemaVersion: raw.schemaVersion,
            action: raw.action,
            navigationGeneration: raw.navigationGeneration,
            target: target
        )
    }
}
