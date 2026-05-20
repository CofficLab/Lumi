import Foundation

enum TestOutputParser {
    static func parse(output: String) -> [JSTestEvent] {
        var events: [JSTestEvent] = []
        let lines = output.components(separatedBy: .newlines)

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let event = parseSymbolLine(line, index: index) {
                events.append(event)
            } else if let event = parsePlaywrightLine(line, index: index) {
                events.append(event)
            }
        }

        return events
    }

    private static func parseSymbolLine(_ line: String, index: Int) -> JSTestEvent? {
        let prefixes: [(String, JSTestEvent.Status)] = [
            ("✓", .passed),
            ("✔", .passed),
            ("PASS", .passed),
            ("✕", .failed),
            ("✖", .failed),
            ("FAIL", .failed),
            ("○", .skipped),
            ("SKIP", .skipped),
        ]

        guard let match = prefixes.first(where: { line.hasPrefix($0.0) }) else { return nil }
        let name = line.dropFirst(match.0.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return JSTestEvent(
            id: "\(index)-\(line)",
            name: name.isEmpty ? line : name,
            file: nil,
            line: nil,
            status: match.1,
            duration: parseDuration(line),
            message: match.1 == .failed ? line : nil
        )
    }

    private static func parsePlaywrightLine(_ line: String, index: Int) -> JSTestEvent? {
        guard line.contains(" passed") || line.contains(" failed") || line.contains(" skipped") else {
            return nil
        }
        let status: JSTestEvent.Status
        if line.contains(" failed") {
            status = .failed
        } else if line.contains(" skipped") {
            status = .skipped
        } else {
            status = .passed
        }
        return JSTestEvent(
            id: "\(index)-\(line)",
            name: line,
            file: nil,
            line: nil,
            status: status,
            duration: parseDuration(line),
            message: status == .failed ? line : nil
        )
    }

    private static func parseDuration(_ line: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"\((\d+(?:\.\d+)?)\s*(ms|s)\)"#) else {
            return nil
        }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let valueRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let value = Double(line[valueRange]) else {
            return nil
        }
        return String(line[unitRange]) == "ms" ? value / 1000 : value
    }
}
