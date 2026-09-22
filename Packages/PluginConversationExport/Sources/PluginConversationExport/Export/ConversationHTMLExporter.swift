import Foundation
import ProviderMessage

struct ConversationExportSnapshot: Sendable {
    let conversationID: UUID
    let title: String
    let createdAt: Date?
    let projectPath: String?
    let providerID: String?
    let modelName: String?
    let messages: [Message]
    let exportedAt: Date
}

struct PreparedConversationExport: Sendable, Equatable {
    let data: Data
    let suggestedFilename: String
}

enum ConversationHTMLExporter {
    static func export(_ snapshot: ConversationExportSnapshot) -> PreparedConversationExport {
        let orderedMessages = snapshot.messages.sorted {
            if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.createdAt < $1.createdAt
        }
        let renderedMessages = orderedMessages.map(renderMessage).joined(separator: "\n")
        let title = escape(snapshot.title)
        let metadata = renderMetadata(snapshot)
        let html = """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="generator" content="Lumi Conversation Export">
          <title>\(title)</title>
          <style>
            :root { color-scheme: light dark; --bg:#f6f7f9; --card:#fff; --text:#1f2328; --muted:#667085; --line:#dfe3e8; --user:#e8f1ff; --assistant:#fff; --system:#fff8df; --tool:#f2edff; --error:#ffeded; }
            @media (prefers-color-scheme: dark) { :root { --bg:#111317; --card:#1b1f24; --text:#e6edf3; --muted:#9da7b3; --line:#343a43; --user:#172d4e; --assistant:#1b1f24; --system:#3a3217; --tool:#2c2345; --error:#431f24; } }
            * { box-sizing:border-box; }
            body { margin:0; background:var(--bg); color:var(--text); font:15px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
            main { width:min(920px,calc(100% - 32px)); margin:36px auto 72px; }
            header { margin-bottom:28px; }
            h1 { margin:0 0 8px; font-size:28px; line-height:1.25; overflow-wrap:anywhere; }
            .metadata { color:var(--muted); display:flex; flex-wrap:wrap; gap:6px 16px; font-size:13px; }
            .message { border:1px solid var(--line); border-radius:14px; margin:14px 0; padding:16px 18px; background:var(--card); box-shadow:0 1px 2px rgba(0,0,0,.04); }
            .message.user { background:var(--user); }
            .message.system,.message.status { background:var(--system); }
            .message.tool { background:var(--tool); }
            .message.error { background:var(--error); }
            .message-head { display:flex; justify-content:space-between; gap:16px; margin-bottom:9px; color:var(--muted); font-size:12px; }
            .role { color:var(--text); font-weight:650; text-transform:capitalize; }
            .content,.detail-content { white-space:pre-wrap; overflow-wrap:anywhere; font-family:inherit; }
            .empty { color:var(--muted); font-style:italic; }
            details { border-top:1px solid var(--line); margin-top:12px; padding-top:10px; }
            summary { cursor:pointer; color:var(--muted); font-weight:600; }
            .attachments { display:grid; gap:10px; margin-top:12px; }
            .attachment { border:1px solid var(--line); border-radius:8px; padding:10px; }
            .attachment a { color:inherit; font-weight:600; }
            .tool-call { border-left:3px solid var(--line); margin:10px 0; padding-left:12px; }
            .tool-name { font-weight:650; }
            pre { white-space:pre-wrap; overflow-wrap:anywhere; background:rgba(127,127,127,.10); border-radius:8px; padding:10px; }
            img { display:block; max-width:100%; height:auto; border-radius:8px; margin-top:10px; }
            footer { color:var(--muted); font-size:12px; margin-top:28px; text-align:center; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <h1>\(title)</h1>
              <div class="metadata">\(metadata)</div>
            </header>
            <section aria-label="Conversation messages">
              \(renderedMessages)
            </section>
            <footer>Exported by Lumi · \(escape(timestamp(snapshot.exportedAt)))</footer>
          </main>
        </body>
        </html>
        """
        return PreparedConversationExport(
            data: Data(html.utf8),
            suggestedFilename: suggestedFilename(title: snapshot.title, date: snapshot.exportedAt)
        )
    }

    private static func renderMetadata(_ snapshot: ConversationExportSnapshot) -> String {
        var values = [
            "<span>\(snapshot.messages.count) messages</span>",
            "<span>ID: \(escape(snapshot.conversationID.uuidString))</span>",
        ]
        if let createdAt = snapshot.createdAt {
            values.append("<span>Created: \(escape(timestamp(createdAt)))</span>")
        }
        if let providerID = nonempty(snapshot.providerID) {
            values.append("<span>Provider: \(escape(providerID))</span>")
        }
        if let modelName = nonempty(snapshot.modelName) {
            values.append("<span>Model: \(escape(modelName))</span>")
        }
        if let projectPath = nonempty(snapshot.projectPath) {
            values.append("<span>Project: \(escape(projectPath))</span>")
        }
        return values.joined()
    }

    private static func renderMessage(_ message: Message) -> String {
        let role = message.role.rawValue
        let roleClass = message.isError ? "error" : role
        let content = nonempty(message.content).map(escape)
            ?? "<span class=\"empty\">No text content</span>"
        let reasoning = nonempty(message.reasoningContent).map {
            "<details><summary>Reasoning</summary><div class=\"detail-content\">\(escape($0))</div></details>"
        } ?? ""
        let toolCalls = renderToolCalls(message.toolCalls ?? [])
        let attachments = renderUserAttachments(message.metadata)
        let model = nonempty(message.modelName).map { " · \(escape($0))" } ?? ""
        return """
        <article class="message \(roleClass)" data-role="\(role)">
          <div class="message-head"><span class="role">\(escape(role))\(model)</span><time datetime="\(escape(timestamp(message.createdAt)))">\(escape(timestamp(message.createdAt)))</time></div>
          <div class="content">\(content)</div>
          \(attachments)
          \(reasoning)
          \(toolCalls)
        </article>
        """
    }

    private static func renderToolCalls(_ calls: [MessageToolCall]) -> String {
        guard !calls.isEmpty else { return "" }
        let items = calls.map { call in
            var body = "<div class=\"tool-call\"><div class=\"tool-name\">\(escape(call.displayDescription ?? call.name))</div>"
            if let arguments = nonempty(call.arguments) {
                body += "<details><summary>Arguments</summary><pre>\(escape(arguments))</pre></details>"
            }
            if let result = call.result {
                body += "<details><summary>Result\(result.isError ? " · Error" : "")</summary>"
                if let resultContent = nonempty(result.content) {
                    body += "<div class=\"detail-content\">\(escape(resultContent))</div>"
                }
                for attachment in result.imageAttachments {
                    if let uri = imageDataURI(attachment) {
                        body += "<img src=\"\(uri)\" alt=\"Tool result image\">"
                    }
                }
                body += "</details>"
            }
            body += "</div>"
            return body
        }.joined()
        return "<details><summary>Tool calls (\(calls.count))</summary>\(items)</details>"
    }

    private static func renderUserAttachments(_ metadata: [String: String]) -> String {
        let images = UserAttachmentMetadata.decodeImageAttachments(from: metadata)
        let files = UserAttachmentMetadata.decodeFileAttachments(from: metadata)
        guard !images.isEmpty || !files.isEmpty else { return "" }

        var items: [String] = images.compactMap { attachment in
            guard let uri = dataURI(
                mimeType: attachment.mimeType,
                data: attachment.base64Data,
                requiredMIMEPrefix: "image/"
            ) else { return nil }
            let name = escape(attachment.fileName ?? "Image attachment")
            return "<div class=\"attachment\"><strong>\(name)</strong><img src=\"\(uri)\" alt=\"\(name)\"></div>"
        }
        items.append(contentsOf: files.map { attachment in
            let name = escape(attachment.fileName)
            let mimeType = escape(attachment.mimeType)
            var body = "<div class=\"attachment\"><strong>\(name)</strong> <span>(\(mimeType))</span>"
            if let uri = dataURI(mimeType: attachment.mimeType, data: attachment.base64Data) {
                body += " · <a href=\"\(uri)\" download=\"\(name)\">Download</a>"
            }
            if let textContent = nonempty(attachment.textContent) {
                body += "<details><summary>File contents</summary><pre>\(escape(textContent))</pre></details>"
            }
            body += "</div>"
            return body
        })
        return "<details open><summary>Attachments (\(images.count + files.count))</summary><div class=\"attachments\">\(items.joined())</div></details>"
    }

    private static func imageDataURI(_ attachment: MessageImageAttachment) -> String? {
        dataURI(mimeType: attachment.mimeType, data: attachment.data, requiredMIMEPrefix: "image/")
    }

    private static func dataURI(
        mimeType rawMIMEType: String,
        data rawData: String?,
        requiredMIMEPrefix: String? = nil
    ) -> String? {
        guard let rawData else { return nil }
        let mimeType = rawMIMEType.lowercased()
        let matchesRequiredPrefix = requiredMIMEPrefix.map(mimeType.hasPrefix) ?? true
        let validMIME = matchesRequiredPrefix && mimeType.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/+.-")).contains($0)
        }
        guard validMIME else { return nil }
        let data = rawData.filter { !$0.isWhitespace }
        let base64 = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        guard !data.isEmpty, data.unicodeScalars.allSatisfy({ base64.contains($0) }) else { return nil }
        return "data:\(mimeType);base64,\(data)"
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func suggestedFilename(title: String, date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(safeFilenameComponent(title))-\(dateFormatter.string(from: date)).html"
    }

    private static func safeFilenameComponent(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters)
        var result = ""
        var previousWasSeparator = false
        for scalar in title.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars {
            let isSeparator = invalid.contains(scalar) || CharacterSet.whitespacesAndNewlines.contains(scalar)
            if isSeparator {
                if !previousWasSeparator && !result.isEmpty { result.append("-") }
                previousWasSeparator = true
            } else {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
        let fallback = trimmed.isEmpty ? "Lumi-Conversation" : trimmed
        return String(fallback.prefix(80))
    }
}
