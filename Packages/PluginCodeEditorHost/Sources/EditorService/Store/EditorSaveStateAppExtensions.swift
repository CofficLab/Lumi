import Foundation

extension EditorSaveState {
    var label: String {
        switch self {
        case .idle: return String(localized: "No Changes", bundle: .module)
        case .editing: return String(localized: "Editing...", bundle: .module)
        case .saving: return String(localized: "Saving...", bundle: .module)
        case .saved: return String(localized: "Saved", bundle: .module)
        case .conflict(let msg): return msg
        case .error(let msg): return msg
        }
    }

}
