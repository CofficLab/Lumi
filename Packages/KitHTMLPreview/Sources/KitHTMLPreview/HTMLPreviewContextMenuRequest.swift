import Foundation

struct HTMLPreviewContextMenuRequest: Decodable, Equatable {
    let schemaVersion: Int
    let action: String
    let requestID: String
    let navigationGeneration: Int
    let clientX: Double
    let clientY: Double
    let candidates: [HTMLPreviewElementReference]
}

enum HTMLPreviewContextMenuRequestError: Error, Equatable {
    case invalidJSON
    case payloadTooLarge
    case unsupportedSchemaVersion
    case invalidAction
    case invalidRequestID
    case invalidCoordinates
    case invalidCandidateCount
    case invalidCandidate
}

enum HTMLPreviewContextMenuRequestDecoder {
    static let maximumPayloadBytes = 128 * 1_024
    static let maximumCandidates = 5
    static let maximumSelectorBytes = 2_048
    static let maximumLabelCharacters = 256
    static let maximumTextCharacters = 512
    static let maximumOuterHTMLBytes = 24 * 1_024
    static let maximumAttributes = 16
    static let maximumAttributeKeyCharacters = 128
    static let maximumAttributeValueCharacters = 1_024
    static let maximumCoordinateMagnitude = 100_000.0

    private static let allowedAttributeNames: Set<String> = [
        "id", "class", "role", "aria-label", "name", "type", "alt", "title",
        "data-block", "data-block-label", "data-prototype-link", "data-prototype-label",
    ]

    static func decode(body: Any) throws -> HTMLPreviewContextMenuRequest {
        guard JSONSerialization.isValidJSONObject(body) else {
            throw HTMLPreviewContextMenuRequestError.invalidJSON
        }

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw HTMLPreviewContextMenuRequestError.invalidJSON
        }
        guard data.count <= maximumPayloadBytes else {
            throw HTMLPreviewContextMenuRequestError.payloadTooLarge
        }

        let raw: HTMLPreviewContextMenuRequest
        do {
            raw = try JSONDecoder().decode(HTMLPreviewContextMenuRequest.self, from: data)
        } catch {
            throw HTMLPreviewContextMenuRequestError.invalidJSON
        }

        guard raw.schemaVersion == HTMLPreviewElementReference.currentSchemaVersion else {
            throw HTMLPreviewContextMenuRequestError.unsupportedSchemaVersion
        }
        guard raw.action == "openContextMenu" else {
            throw HTMLPreviewContextMenuRequestError.invalidAction
        }
        guard !raw.requestID.isEmpty, raw.requestID.count <= 128 else {
            throw HTMLPreviewContextMenuRequestError.invalidRequestID
        }
        guard raw.clientX.isFinite,
              raw.clientY.isFinite,
              abs(raw.clientX) <= maximumCoordinateMagnitude,
              abs(raw.clientY) <= maximumCoordinateMagnitude else {
            throw HTMLPreviewContextMenuRequestError.invalidCoordinates
        }
        guard (1...maximumCandidates).contains(raw.candidates.count) else {
            throw HTMLPreviewContextMenuRequestError.invalidCandidateCount
        }

        let candidates = try raw.candidates.map(normalize)
        return HTMLPreviewContextMenuRequest(
            schemaVersion: raw.schemaVersion,
            action: raw.action,
            requestID: raw.requestID,
            navigationGeneration: raw.navigationGeneration,
            clientX: raw.clientX,
            clientY: raw.clientY,
            candidates: candidates
        )
    }

    private static func normalize(_ candidate: HTMLPreviewElementReference) throws -> HTMLPreviewElementReference {
        guard candidate.schemaVersion == HTMLPreviewElementReference.currentSchemaVersion,
              !candidate.selector.isEmpty,
              candidate.selector.utf8.count <= maximumSelectorBytes,
              !candidate.tagName.isEmpty,
              candidate.tagName.count <= 64,
              candidate.label.count <= maximumLabelCharacters,
              candidate.outerHTML.utf8.count <= maximumOuterHTMLBytes,
              candidate.attributes.count <= maximumAttributes else {
            throw HTMLPreviewContextMenuRequestError.invalidCandidate
        }

        let label = normalizedDisplayText(candidate.label)
        guard !label.isEmpty, label.count <= maximumLabelCharacters else {
            throw HTMLPreviewContextMenuRequestError.invalidCandidate
        }

        let textPreview = candidate.textPreview.map(normalizedDisplayText)
        guard textPreview?.count ?? 0 <= maximumTextCharacters else {
            throw HTMLPreviewContextMenuRequestError.invalidCandidate
        }

        let allowedAttributes = try candidate.attributes.reduce(into: [String: String]()) { result, entry in
            let key = entry.key.lowercased()
            guard allowedAttributeNames.contains(key) else { return }
            guard key.count <= maximumAttributeKeyCharacters,
                  entry.value.count <= maximumAttributeValueCharacters else {
                throw HTMLPreviewContextMenuRequestError.invalidCandidate
            }
            result[key] = entry.value
        }

        return HTMLPreviewElementReference(
            selector: candidate.selector,
            tagName: candidate.tagName.lowercased(),
            label: label,
            textPreview: textPreview?.isEmpty == false ? textPreview : nil,
            outerHTML: candidate.outerHTML,
            isOuterHTMLTruncated: candidate.isOuterHTMLTruncated,
            blockID: normalizedOptional(candidate.blockID),
            blockLabel: normalizedOptional(candidate.blockLabel),
            attributes: allowedAttributes
        )
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = normalizedDisplayText(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedDisplayText(_ value: String) -> String {
        let scalars = value.unicodeScalars.map { scalar -> Character in
            if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return " "
            }
            return Character(String(scalar))
        }
        return String(scalars)
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}
