import Foundation

/// One styled run inside an inline text (paragraph / heading / list item).
public struct AppKitInlineRun: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case plain
        case bold
        case italic
        case code
        case link(url: String)
    }

    public let range: NSRange
    public let kind: Kind

    public init(range: NSRange, kind: Kind) {
        self.range = range
        self.kind = kind
    }
}

/// Parses inline Markdown markers (`**bold**`, `*italic*`, `` `code` ``,
/// `[text](url)`) into attribute runs over the source text.
///
/// Pure value output (no `NSAttributedString`) so results are Sendable and can
/// be cached; Task 9 applies the runs to a TextKit string during rendering.
public enum AppKitInlineMarkdownFormatter {
    public static func parseRuns(in text: String) -> [AppKitInlineRun] {
        let ns = text as NSString
        var runs: [AppKitInlineRun] = []
        let length = ns.length
        guard length > 0 else { return [] }

        // Scan for the earliest marker; plain text fills the gaps.
        var cursor = 0
        while cursor < length {
            guard let next = nextMarker(in: ns, from: cursor) else {
                runs.append(AppKitInlineRun(
                    range: NSRange(location: cursor, length: length - cursor),
                    kind: .plain
                ))
                break
            }

            if next.location > cursor {
                runs.append(AppKitInlineRun(
                    range: NSRange(location: cursor, length: next.location - cursor),
                    kind: .plain
                ))
            }

            switch next.marker {
            case .code:
                let contentStart = next.location + 1
                let contentEnd = closingMarker(ns, marker: "`", from: contentStart)
                let contentLength = contentEnd - contentStart
                runs.append(AppKitInlineRun(
                    range: NSRange(location: contentStart, length: max(0, contentLength)),
                    kind: .code
                ))
                cursor = contentEnd + 1
            case .bold:
                let contentStart = next.location + 2
                let contentEnd = closingMarker(ns, marker: "**", from: contentStart)
                let contentLength = contentEnd - contentStart
                runs.append(AppKitInlineRun(
                    range: NSRange(location: contentStart, length: max(0, contentLength)),
                    kind: .bold
                ))
                cursor = contentEnd + 2
            case .italic:
                let contentStart = next.location + 1
                let contentEnd = closingMarker(ns, marker: "*", from: contentStart)
                let contentLength = contentEnd - contentStart
                runs.append(AppKitInlineRun(
                    range: NSRange(location: contentStart, length: max(0, contentLength)),
                    kind: .italic
                ))
                cursor = contentEnd + 1
            case .link:
                // [label](url): parse label and URL segments.
                let labelStart = next.location + 1
                let labelEnd = ns.range(
                    of: "]",
                    options: [],
                    range: NSRange(location: labelStart, length: length - labelStart)
                ).location
                let urlOpen = labelEnd == NSNotFound ? NSNotFound : labelEnd + 1
                if urlOpen != NSNotFound, urlOpen < length, ns.character(at: urlOpen) == 0x28 {
                    let urlClose = ns.range(
                        of: ")",
                        options: [],
                        range: NSRange(location: urlOpen, length: length - urlOpen)
                    ).location
                    if urlClose != NSNotFound {
                        let url = ns.substring(with: NSRange(
                            location: urlOpen + 1,
                            length: urlClose - urlOpen - 1
                        ))
                        runs.append(AppKitInlineRun(
                            range: NSRange(location: labelStart, length: labelEnd - labelStart),
                            kind: .link(url: url)
                        ))
                        cursor = urlClose + 1
                        continue
                    }
                }
                // Malformed link → treat as plain and advance.
                runs.append(AppKitInlineRun(
                    range: NSRange(location: next.location, length: 1),
                    kind: .plain
                ))
                cursor = next.location + 1
            }
        }
        return runs
    }

    // MARK: - Scanning helpers

    private enum Marker {
        case code
        case bold
        case italic
        case link
    }

    private struct Match {
        let location: Int
        let marker: Marker
    }

    private static func nextMarker(in ns: NSString, from cursor: Int) -> Match? {
        let length = ns.length
        var best: Match?

        func consider(_ marker: Marker, at index: Int) {
            if index == NSNotFound { return }
            if best == nil || index < best!.location {
                best = Match(location: index, marker: marker)
            }
        }

        consider(.code, at: ns.range(of: "`", options: [], range: NSRange(location: cursor, length: length - cursor)).location)
        consider(.bold, at: ns.range(of: "**", options: [], range: NSRange(location: cursor, length: length - cursor)).location)
        consider(.italic, at: ns.range(of: "*", options: [], range: NSRange(location: cursor, length: length - cursor)).location)
        consider(.link, at: ns.range(of: "[", options: [], range: NSRange(location: cursor, length: length - cursor)).location)
        return best
    }

    private static func closingMarker(_ ns: NSString, marker: String, from start: Int) -> Int {
        let length = ns.length
        guard start < length else { return start }
        let found = ns.range(of: marker, options: [], range: NSRange(location: start, length: length - start))
        return found.location == NSNotFound ? length : found.location
    }
}
