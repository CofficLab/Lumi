import Foundation

/// Value-type copy of the fields needed to render an export document.
///
/// SwiftData models are not safe to read off the context's main actor, so the
/// settings view snapshots records into this `Sendable` struct before handing
/// them to a background export task.
public struct HTTPExchangeExportSnapshot: Sendable, Identifiable {
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
    /// `00001-GET-api.github.com-users-octocat-<UUID>.md`.
    ///
    /// 批内序号只在同一批次内唯一：不同批次都从 `00001` 开始，同一方法/URL 的
    /// 不同 exchange 会算出完全相同的路径，`document.write(atomically:)` 会
    /// 静默覆盖上一次归档。因此文件名必须带上 exchange ID。
    static func exportFileName(for snapshot: HTTPExchangeExportSnapshot, index: Int) -> String {
        var name = String(format: "%05d-", index + 1) + snapshot.method + "-"
        if let url = URL(string: snapshot.url) {
            if let host = url.host { name += host }
            let path = url.path.replacingOccurrences(of: "/", with: "-")
            if !path.isEmpty { name += path }
        }
        var cleaned = name.replacingOccurrences(of: "[/\\\\:?%*|\"<>]", with: "_", options: .regularExpression)
        // 截断只作用于描述性前缀：ID 后缀必须完整保留，否则长 URL 会重新碰撞。
        if cleaned.count > 90 {
            cleaned = String(cleaned.prefix(90))
        }
        // 90 个字符可能是 270+ UTF-8 字节（CJK/emoji），仍超 APFS 单组件 255 字节限；
        // 再按最终文件名的字节预算截断，不切断字素簇（#822）。
        let tail = "-" + snapshot.id.uuidString + ".md"
        let component = truncateToUTF8Bytes(cleaned, budget: maxFilenameBytes - tail.utf8.count)
        return component + tail
    }

    static func text(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let pretty = String(data: prettyData, encoding: .utf8) { return pretty }
        if let text = String(data: data, encoding: .utf8) { return text }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    /// Returns the raw text representation without JSON pretty-printing.
    /// Falls back to UTF-8 text, then hex dump.
    static func rawText(_ data: Data?) -> String {
        guard let data, !data.isEmpty else { return "<empty>" }
        if let text = String(data: data, encoding: .utf8) { return text }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func fenced(_ value: String, language: String) -> String {
        "```\(language)\n\(value)\n```"
    }

    /// APFS 单个路径组件的 UTF-8 字节上限。
    private static let maxFilenameBytes = 255

    /// 按 UTF-8 字节预算截断：逐字素簇累加，超出预算即停，保证不切断字符、Unicode 有效。
    private static func truncateToUTF8Bytes(_ value: String, budget: Int) -> String {
        guard budget > 0 else { return "" }
        if value.utf8.count <= budget { return value }
        var result = ""
        var bytes = 0
        for character in value {
            let size = String(character).utf8.count
            if bytes + size > budget { break }
            result.append(character)
            bytes += size
        }
        return result
    }

    /// One record that could not be written during a batch export.
    struct ExportWriteFailure: Sendable {
        let index: Int
        let fileName: String
        let errorDescription: String
    }

    /// Writes one markdown file per snapshot into `directory`, each inside its
    /// own `do/catch` so a single failure is collected and the batch continues
    /// rather than discarding the remaining records (#822). `onWritten` runs
    /// after each successful write to let the caller advance progress.
    static func writeBatch(
        _ snapshots: [HTTPExchangeExportSnapshot],
        to directory: URL,
        onWritten: (@Sendable (Int) async -> Void)? = nil
    ) async -> [ExportWriteFailure] {
        var failures: [ExportWriteFailure] = []
        for (index, snapshot) in snapshots.enumerated() {
            let fileName = exportFileName(for: snapshot, index: index)
            do {
                let document = document(for: snapshot)
                try document.write(
                    to: directory.appendingPathComponent(fileName),
                    atomically: true,
                    encoding: .utf8
                )
                await onWritten?(index)
            } catch {
                failures.append(
                    ExportWriteFailure(index: index, fileName: fileName, errorDescription: error.localizedDescription)
                )
            }
        }
        return failures
    }
}
