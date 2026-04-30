import Foundation

struct EditorSnippetParseResult: Equatable {
    let text: String
    let groups: [EditorSnippetSession.PlaceholderGroup]
    let exitSelection: NSRange
}

enum EditorSnippetParser {
    static func parse(_ snippet: String) -> EditorSnippetParseResult {
        let ns = snippet as NSString
        var index = 0
        var output = ""
        var placeholders: [Int: [NSRange]] = [:]
        var placeholderSeeds: [Int: String] = [:]
        var exitSelection = NSRange(location: 0, length: 0)
        var hasExplicitExit = false

        func appendPlaceholder(index placeholderIndex: Int, text: String) {
            let location = (output as NSString).length
            output.append(text)
            let range = NSRange(location: location, length: (text as NSString).length)
            if placeholderIndex == 0 {
                exitSelection = range
                hasExplicitExit = true
            } else {
                placeholders[placeholderIndex, default: []].append(range)
                if placeholderSeeds[placeholderIndex] == nil {
                    placeholderSeeds[placeholderIndex] = text
                }
            }
        }

        while index < ns.length {
            let char = ns.character(at: index)

            if char == 0x5C { // "\"
                if index + 1 < ns.length {
                    output.append(ns.substring(with: NSRange(location: index + 1, length: 1)))
                    index += 2
                } else {
                    index += 1
                }
                continue
            }

            guard char == 0x24 else { // "$"
                output.append(ns.substring(with: NSRange(location: index, length: 1)))
                index += 1
                continue
            }

            if index + 1 >= ns.length {
                output.append("$")
                index += 1
                continue
            }

            let next = ns.character(at: index + 1)
            if next >= 0x30, next <= 0x39 {
                let placeholderIndex = Int(next - 0x30)
                let seededText = placeholderSeeds[placeholderIndex] ?? ""
                appendPlaceholder(index: placeholderIndex, text: seededText)
                index += 2
                continue
            }

            if next == 0x7B { // "{"
                var cursor = index + 2
                var digits = ""
                while cursor < ns.length {
                    let value = ns.character(at: cursor)
                    guard value >= 0x30, value <= 0x39 else { break }
                    digits.append(ns.substring(with: NSRange(location: cursor, length: 1)))
                    cursor += 1
                }

                guard let placeholderIndex = Int(digits), cursor < ns.length else {
                    output.append("$")
                    index += 1
                    continue
                }

                let delimiter = ns.character(at: cursor)
                if delimiter == 0x7D { // "}"
                    let seededText = placeholderSeeds[placeholderIndex] ?? ""
                    appendPlaceholder(index: placeholderIndex, text: seededText)
                    index = cursor + 1
                    continue
                }

                if delimiter == 0x3A { // ":"
                    cursor += 1
                    var body = ""
                    while cursor < ns.length {
                        let bodyChar = ns.character(at: cursor)
                        if bodyChar == 0x5C, cursor + 1 < ns.length {
                            body.append(ns.substring(with: NSRange(location: cursor + 1, length: 1)))
                            cursor += 2
                            continue
                        }
                        if bodyChar == 0x7D { break }
                        body.append(ns.substring(with: NSRange(location: cursor, length: 1)))
                        cursor += 1
                    }

                    if cursor < ns.length, ns.character(at: cursor) == 0x7D {
                        let seededText = placeholderSeeds[placeholderIndex] ?? body
                        appendPlaceholder(index: placeholderIndex, text: seededText)
                        if placeholderSeeds[placeholderIndex] == nil {
                            placeholderSeeds[placeholderIndex] = body
                        }
                        index = cursor + 1
                        continue
                    }
                }
            }

            output.append("$")
            index += 1
        }

        let groups = placeholders.keys.sorted().map { placeholderIndex in
            EditorSnippetSession.PlaceholderGroup(
                index: placeholderIndex,
                ranges: placeholders[placeholderIndex] ?? []
            )
        }

        if !hasExplicitExit {
            let end = (output as NSString).length
            exitSelection = NSRange(location: end, length: 0)
        }

        return EditorSnippetParseResult(
            text: output,
            groups: groups,
            exitSelection: exitSelection
        )
    }
}
