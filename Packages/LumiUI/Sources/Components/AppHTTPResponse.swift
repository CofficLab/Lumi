import Foundation

/// HTTP response payload for `AppHTTPResponseView`.
public struct AppHTTPResponse: Equatable, Sendable {
    public let statusCode: Int?
    public let body: String?

    public init(statusCode: Int? = nil, body: String? = nil) {
        self.statusCode = statusCode
        self.body = body
    }

    public var trimmedBody: String {
        body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    public var hasBody: Bool {
        !trimmedBody.isEmpty
    }

    /// Text copied to the pasteboard, including status and body sections.
    public var copyText: String {
        var sections: [String] = []
        if let statusCode {
            sections.append("HTTP Status: \(statusCode)")
        }
        if hasBody {
            sections.append("Response Body:")
            sections.append(trimmedBody)
        }
        return sections.joined(separator: "\n")
    }

    public static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    public static func prettyPrintedJSON(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return nil
        }
        return pretty
    }

    public func displayBody(pretty: Bool) -> String {
        let raw = trimmedBody
        guard pretty, let formatted = Self.prettyPrintedJSON(from: raw) else {
            return raw
        }
        return formatted
    }

    public static func statusPhrase(for statusCode: Int) -> String {
        HTTPURLResponse.localizedString(forStatusCode: statusCode)
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

public enum AppHTTPStatusTone: Equatable, Sendable {
    case success
    case redirect
    case clientError
    case serverError
    case informational
    case unknown

    public static func tone(for statusCode: Int) -> AppHTTPStatusTone {
        switch statusCode {
        case 100 ..< 200:
            return .informational
        case 200 ..< 300:
            return .success
        case 300 ..< 400:
            return .redirect
        case 400 ..< 500:
            return .clientError
        case 500 ..< 600:
            return .serverError
        default:
            return .unknown
        }
    }
}
