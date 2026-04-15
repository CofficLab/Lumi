import Foundation

enum LumiMultiCursorOperation {
    case replaceSelection(String)
    case insert(String)
    case deleteBackward
}

struct LumiMultiCursorEditResult {
    let text: String
    let selections: [LumiMultiCursorSelection]
}

/// 多光标编辑引擎
/// 以“从后往前”顺序应用编辑，避免前序编辑导致后续 range 偏移
enum LumiMultiCursorEditEngine {

    static func apply(
        text: String,
        selections: [LumiMultiCursorSelection],
        operation: LumiMultiCursorOperation
    ) -> LumiMultiCursorEditResult {
        guard !selections.isEmpty else {
            return .init(text: text, selections: [])
        }

        var buffer = text
        let ns = NSMutableString(string: buffer)
        let ordered = selections
            .map { normalized($0, maxLength: ns.length) }
            .sorted { $0.location > $1.location }

        var newSelections: [LumiMultiCursorSelection] = []

        for sel in ordered {
            let safe = normalized(sel, maxLength: ns.length)
            switch operation {
            case .replaceSelection(let content):
                ns.replaceCharacters(in: NSRange(location: safe.location, length: safe.length), with: content)
                newSelections.append(.init(location: safe.location + (content as NSString).length, length: 0))

            case .insert(let content):
                if safe.length > 0 {
                    ns.replaceCharacters(in: NSRange(location: safe.location, length: safe.length), with: content)
                    newSelections.append(.init(location: safe.location + (content as NSString).length, length: 0))
                } else {
                    ns.insert(content, at: safe.location)
                    newSelections.append(.init(location: safe.location + (content as NSString).length, length: 0))
                }

            case .deleteBackward:
                if safe.length > 0 {
                    ns.deleteCharacters(in: NSRange(location: safe.location, length: safe.length))
                    newSelections.append(.init(location: safe.location, length: 0))
                } else if safe.location > 0 {
                    ns.deleteCharacters(in: NSRange(location: safe.location - 1, length: 1))
                    newSelections.append(.init(location: safe.location - 1, length: 0))
                } else {
                    newSelections.append(safe)
                }
            }
        }

        buffer = ns as String
        return .init(text: buffer, selections: newSelections.sorted { $0.location < $1.location })
    }

    private static func normalized(_ selection: LumiMultiCursorSelection, maxLength: Int) -> LumiMultiCursorSelection {
        let location = min(max(0, selection.location), maxLength)
        let maxSelectable = max(0, maxLength - location)
        let length = min(max(0, selection.length), maxSelectable)
        return .init(location: location, length: length)
    }
}
