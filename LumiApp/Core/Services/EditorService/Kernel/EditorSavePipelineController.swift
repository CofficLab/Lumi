import Foundation

enum EditorDeferredSaveAction: String, CaseIterable, Equatable, Sendable {
    case organizeImports
    case fixAll
}

struct EditorSavePipelineOptions: Equatable, Sendable {
    var textParticipants: EditorSaveParticipantOptions
    var formatOnSave: Bool
    var organizeImportsOnSave: Bool
    var fixAllOnSave: Bool

    static let `default` = EditorSavePipelineOptions(
        textParticipants: .default,
        formatOnSave: false,
        organizeImportsOnSave: false,
        fixAllOnSave: false
    )
}

struct EditorSavePipelineResult: Equatable, Sendable {
    let text: String
    let didApplyTextParticipants: Bool
    let didFormat: Bool
    let deferredActions: [EditorDeferredSaveAction]

    var changed: Bool {
        didApplyTextParticipants || didFormat
    }
}

enum EditorSavePipelineController {
    @MainActor
    static func prepare(
        text: String,
        options: EditorSavePipelineOptions = .default,
        tabSize: Int,
        insertSpaces: Bool,
        formatDocument: ((_ text: String, _ tabSize: Int, _ insertSpaces: Bool) async -> String?)? = nil
    ) async -> EditorSavePipelineResult {
        let participantResult = EditorSaveParticipantController.prepare(
            text: text,
            options: options.textParticipants
        )

        var transformed = participantResult.text
        var didFormat = false

        if options.formatOnSave,
           let formatDocument,
           let formatted = await formatDocument(transformed, tabSize, insertSpaces),
           formatted != transformed {
            transformed = formatted
            didFormat = true
        }

        var deferredActions: [EditorDeferredSaveAction] = []
        if options.organizeImportsOnSave {
            deferredActions.append(.organizeImports)
        }
        if options.fixAllOnSave {
            deferredActions.append(.fixAll)
        }

        return EditorSavePipelineResult(
            text: transformed,
            didApplyTextParticipants: participantResult.changed,
            didFormat: didFormat,
            deferredActions: deferredActions
        )
    }
}
