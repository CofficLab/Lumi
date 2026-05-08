import Foundation

extension EditorSaveState {
    var label: String {
        switch self {
        case .idle: return String(localized: "No Changes", table: EditorHostEnvironment.current.localizationTable)
        case .editing: return String(localized: "Editing...", table: EditorHostEnvironment.current.localizationTable)
        case .saving: return String(localized: "Saving...", table: EditorHostEnvironment.current.localizationTable)
        case .saved: return String(localized: "Saved", table: EditorHostEnvironment.current.localizationTable)
        case .conflict(let msg): return msg
        case .error(let msg): return msg
        }
    }

}
