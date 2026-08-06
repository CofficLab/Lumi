import Foundation

/// Value-type copy of the fields needed to render an export document.
///
/// SwiftData models are not safe to read off the context's main actor, so the
/// settings view snapshots records into this `Sendable` struct before handing
/// them to a background export task.
public struct HTTPExchangeExportSnapshot: Sendable {
    public let id: UUID
    public let method: String
    public let url: String
    public let startedAt: Date
    public let finishedAt: Date?
    public let duration: TimeInterval?
    public let requestHeadersJSON: Data
    public let requestBody: Data?
    public let requestDetailsJSON: Data
    public let responseURL: String?
    public let responseStatusCode: Int?
    public let responseHTTPVersion: String?
    public let responseMIMEType: String?
    public let responseHeadersJSON: Data?
    public let responseBody: Data?
    public let errorDescription: String?
    public let errorDomain: String?
    public let errorCode: Int?
    public let errorDetailsJSON: Data?

    public init(record: HTTPExchangeRecord) {
        self.id = record.id
        self.method = record.requestMethod
        self.url = record.requestURL
        self.startedAt = record.startedAt
        self.finishedAt = record.finishedAt
        self.duration = record.duration
        self.requestHeadersJSON = record.requestHeadersJSON
        self.requestBody = record.requestBody
        self.requestDetailsJSON = record.requestDetailsJSON
        self.responseURL = record.responseURL
        self.responseStatusCode = record.responseStatusCode
        self.responseHTTPVersion = record.responseHTTPVersion
        self.responseMIMEType = record.responseMIMEType
        self.responseHeadersJSON = record.responseHeadersJSON
        self.responseBody = record.responseBody
        self.errorDescription = record.errorDescription
        self.errorDomain = record.errorDomain
        self.errorCode = record.errorCode
        self.errorDetailsJSON = record.errorDetailsJSON
    }
}

enum HTTPExchangeExportFormatter {
    static func document(for record: HTTPExchangeRecord) -> String {
        document(for: HTTPExchangeExportSnapshot(record: record))
    }

    static func document(for snapshot: HTTPExchangeExportSnapshot) -> String {
        var sections = [
            "# HTTP Exchange",
            "",
            "## Summary",
            "- ID: `\(snapshot.id.uuidString)`",
            "- Method: `\(snapshot.method)`",
            "- URL: \(snapshot.url)",
            "- Started At: \(snapshot.startedAt.formatted(.iso8601))",
        ]
        if let finishedAt = snapshot.finishedAt { sections.append("- Finished At: \(finishedAt.formatted(.iso8601))") }
        if let duration = snapshot.duration { sections.append(String(format: "- Duration: %.3f s", duration)) }

        sections += [
            "", "## Request", "", "### Headers", fenced(text(snapshot.requestHeadersJSON), language: "json"),
            "", "### Body", fenced(text(snapshot.requestBody), language: "json"),
            "", "### Request Options", fenced(text(snapshot.requestDetailsJSON), language: "json"),
            "", "## Response", "", "- Status: \(snapshot.responseStatusCode.map(String.init) ?? "Pending")",
        ]
        if let responseURL = snapshot.responseURL { sections.append("- URL: \(responseURL)") }
        if let version = snapshot.responseHTTPVersion { sections.append("- HTTP Version: \(version)") }
        if let mimeType = snapshot.responseMIMEType { sections.append("- MIME Type: \(mimeType)") }
        sections += [
            "", "### Headers", fenced(text(snapshot.responseHeadersJSON), language: "json"),
            "", "### Body", fenced(text(snapshot.responseBody), language: "json"),
        ]

        if let errorDescription = snapshot.errorDescription {
            sections += ["", "## Error", "", errorDescription]
            if let domain = snapshot.errorDomain, let code = snapshot.errorCode {
                sections += ["- Domain: `\(domain)`", "- Code: `\(code)`"]
            }
            if let details = snapshot.errorDetailsJSON {
                sections += ["", "### Error Details", fenced(text(details), language: "json")]
            }
        }
        return sections.joined(separator: "\n") + "\n"
    }

    /// Export multiple records into a single markdown document.
    ///
    /// Keeps the full per-record layout; a numbered H1 replaces the default
    /// "# HTTP Exchange" header so entries are easy to scan in one file.
    static func document(for records: [HTTPExchangeRecord], filterTitle: String? = nil) -> String {
        document(for: records.map(HTTPExchangeExportSnapshot.init), filterTitle: filterTitle)
    }

    /// Builds a batch document from already-snapshotted records.
    ///
    /// `updateProgress` is invoked on the calling thread after each record is
    /// rendered, letting a background task report progress without coupling
    /// the formatter to any UI type.
    static func document(
        for snapshots: [HTTPExchangeExportSnapshot],
        filterTitle: String? = nil,
        updateProgress: (() -> Void)? = nil
    ) -> String {
        var sections = [
            "# HTTP Exchange Logs",
            "",
            "## Summary",
        ]
        if let filterTitle, !filterTitle.isEmpty {
            sections.append("- Filter: `\(filterTitle)`")
        }
        sections += [
            "- Total: \(snapshots.count)",
            "- Exported At: \(Date().formatted(.iso8601))",
        ]

        for (index, snapshot) in snapshots.enumerated() {
            var single = document(for: snapshot)
            let header = "# \(index + 1). \(snapshot.method) \(snapshot.url)"
            if let newline = single.firstIndex(of: "\n") {
                single.replaceSubrange(single.startIndex..<newline, with: header)
            } else {
                single = header
            }
            sections += ["", "---", "", single]
            updateProgress?()
        }
        return sections.joined(separator: "\n") + "\n"
    }

    /// Stable, filesystem-safe file name for one exported record, e.g.
    /// `00001-GET-api.github.com-users-octocat.md`. The zero-padded sequence
    /// keeps files unique even when multiple records share the same URL.
    static func exportFileName(for snapshot: HTTPExchangeExportSnapshot, index: Int) -> String {
        var name = String(format: "%05d-", index + 1) + snapshot.method + "-"
        if let url = URL(string: snapshot.url) {
            if let host = url.host { name += host }
            let path = url.path.replacingOccurrences(of: "/", with: "-")
            if !path.isEmpty { name += path }
        }
        let cleaned = name.replacingOccurrences(of: "[/\\\\:?%*|\"<>]", with: "_", options: .regularExpression)
        if cleaned.count > 120 {
            return String(cleaned.prefix(120)) + ".md"
        }
        return cleaned + ".md"
    }

    static func text(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let pretty = String(data: prettyData, encoding: .utf8) { return pretty }
        if let text = String(data: data, encoding: .utf8) { return text }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func fenced(_ value: String, language: String) -> String {
        "```\(language)\n\(value)\n```"
    }
}
