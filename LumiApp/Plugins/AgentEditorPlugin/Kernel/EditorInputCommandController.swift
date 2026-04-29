import Foundation

@MainActor
final class EditorInputCommandController {
    enum CursorMotionPlan {
        case selections([NSRange])
        case transaction(EditorTransaction)
    }

    func lineEditResult(
        kind: LineEditKind,
        text: String,
        selections: [NSRange],
        languageId: String
    ) -> LineEditResult? {
        switch kind {
        case .deleteLine:
            return LineEditingController.deleteLine(in: text, selections: selections)
        case .copyLineUp:
            return LineEditingController.copyLineUp(in: text, selections: selections)
        case .copyLineDown:
            return LineEditingController.copyLineDown(in: text, selections: selections)
        case .moveLineUp:
            return LineEditingController.moveLineUp(in: text, selections: selections)
        case .moveLineDown:
            return LineEditingController.moveLineDown(in: text, selections: selections)
        case .insertLineBelow:
            return LineEditingController.insertLineBelow(in: text, selections: selections)
        case .insertLineAbove:
            return LineEditingController.insertLineAbove(in: text, selections: selections)
        case .sortLinesAscending:
            return LineEditingController.sortLines(in: text, selections: selections, descending: false)
        case .sortLinesDescending:
            return LineEditingController.sortLines(in: text, selections: selections, descending: true)
        case .toggleLineComment:
            return LineEditingController.toggleLineComment(
                in: text,
                selections: selections,
                commentPrefix: commentPrefix(for: languageId)
            )
        case .transpose:
            return LineEditingController.transpose(in: text, selections: selections)
        }
    }

    func cursorMotionPlan(
        kind: CursorMotionKind,
        text: String,
        currentLocation: Int,
        currentRange: NSRange
    ) -> CursorMotionPlan? {
        switch kind {
        case .wordLeft:
            return .selections([collapsedSelection(at: CursorMotionController.moveWordLeft(location: currentLocation, text: text).location)])
        case .wordRight:
            return .selections([collapsedSelection(at: CursorMotionController.moveWordRight(location: currentLocation, text: text).location)])
        case .wordLeftSelect:
            return .selections([selectionExpanding(from: currentRange.location, to: CursorMotionController.moveWordLeft(location: currentLocation, text: text).location)])
        case .wordRightSelect:
            return .selections([selectionExpanding(from: currentRange.location, to: CursorMotionController.moveWordRight(location: currentLocation, text: text).location)])
        case .smartHome:
            return .selections([collapsedSelection(at: CursorMotionController.smartHome(location: currentLocation, text: text).location)])
        case .smartHomeSelect:
            return .selections([selectionExpanding(from: currentRange.location, to: CursorMotionController.smartHome(location: currentLocation, text: text).location)])
        case .lineEnd:
            return .selections([collapsedSelection(at: CursorMotionController.moveToEndOfLine(location: currentLocation, text: text).location)])
        case .lineEndSelect:
            return .selections([selectionExpanding(from: currentRange.location, to: CursorMotionController.moveToEndOfLine(location: currentLocation, text: text).location)])
        case .documentStart:
            return .selections([collapsedSelection(at: CursorMotionController.moveToDocumentStart().location)])
        case .documentEnd:
            return .selections([collapsedSelection(at: CursorMotionController.moveToDocumentEnd(text: text).location)])
        case .deleteWordLeft:
            let target = CursorMotionController.deleteWordLeft(location: currentLocation, text: text)
            guard let deleteRange = target.selectionRange else { return nil }
            return .transaction(
                EditorTransaction(
                    replacements: [
                        .init(
                            range: EditorRange(location: deleteRange.location, length: deleteRange.length),
                            text: ""
                        )
                    ],
                    updatedSelections: [EditorSelection(range: EditorRange(location: target.location, length: 0))]
                )
            )
        case .deleteWordRight:
            let target = CursorMotionController.deleteWordRight(location: currentLocation, text: text)
            guard let deleteRange = target.selectionRange else { return nil }
            return .transaction(
                EditorTransaction(
                    replacements: [
                        .init(
                            range: EditorRange(location: deleteRange.location, length: deleteRange.length),
                            text: ""
                        )
                    ],
                    updatedSelections: [EditorSelection(range: EditorRange(location: currentLocation, length: 0))]
                )
            )
        case .paragraphBackward:
            return .selections([collapsedSelection(at: CursorMotionController.moveParagraphBackward(location: currentLocation, text: text).location)])
        case .paragraphForward:
            return .selections([collapsedSelection(at: CursorMotionController.moveParagraphForward(location: currentLocation, text: text).location)])
        }
    }

    private func collapsedSelection(at location: Int) -> NSRange {
        NSRange(location: location, length: 0)
    }

    private func selectionExpanding(from anchor: Int, to location: Int) -> NSRange {
        NSRange(location: min(anchor, location), length: abs(location - anchor))
    }

    private func commentPrefix(for languageId: String) -> String {
        switch languageId {
        case "swift", "java", "javascript", "typescript", "go", "rust", "kotlin", "c", "cpp":
            return "//"
        case "python", "ruby", "perl", "r", "bash", "shell", "yaml", "toml":
            return "#"
        case "html", "xml", "svg":
            return "<!--"
        case "css", "scss", "less":
            return "/*"
        case "lua", "sql":
            return "--"
        default:
            return "//"
        }
    }
}
