import Foundation

enum HTTPExchangeExportFormatter {
    static func document(for record: HTTPExchangeRecord) -> String {
        var sections = [
            "# HTTP Exchange",
            "",
            "## Summary",
            "- ID: `\(record.id.uuidString)`",
            "- Method: `\(record.requestMethod)`",
            "- URL: \(record.requestURL)",
            "- Started At: \(record.startedAt.formatted(.iso8601))",
        ]
        if let finishedAt = record.finishedAt { sections.append("- Finished At: \(finishedAt.formatted(.iso8601))") }
        if let duration = record.duration { sections.append(String(format: "- Duration: %.3f s", duration)) }

        sections += [
            "", "## Request", "", "### Headers", fenced(text(record.requestHeadersJSON), language: "json"),
            "", "### Body", fenced(text(record.requestBody), language: "json"),
            "", "### Request Options", fenced(text(record.requestDetailsJSON), language: "json"),
            "", "## Response", "", "- Status: \(record.responseStatusCode.map(String.init) ?? "Pending")",
        ]
        if let responseURL = record.responseURL { sections.append("- URL: \(responseURL)") }
        if let version = record.responseHTTPVersion { sections.append("- HTTP Version: \(version)") }
        if let mimeType = record.responseMIMEType { sections.append("- MIME Type: \(mimeType)") }
        sections += [
            "", "### Headers", fenced(text(record.responseHeadersJSON), language: "json"),
            "", "### Body", fenced(text(record.responseBody), language: "json"),
        ]

        if let errorDescription = record.errorDescription {
            sections += ["", "## Error", "", errorDescription]
            if let domain = record.errorDomain, let code = record.errorCode {
                sections += ["- Domain: `\(domain)`", "- Code: `\(code)`"]
            }
            if let details = record.errorDetailsJSON {
                sections += ["", "### Error Details", fenced(text(details), language: "json")]
            }
        }
        return sections.joined(separator: "\n") + "\n"
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
