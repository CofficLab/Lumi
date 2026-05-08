import Foundation

extension EditorSaveState {
    var label: String {
        switch self {
        case .idle: return String(localized: "No Changes", table: "LumiEditor")
        case .editing: return String(localized: "Editing...", table: "LumiEditor")
        case .saving: return String(localized: "Saving...", table: "LumiEditor")
        case .saved: return String(localized: "Saved", table: "LumiEditor")
        case .conflict(let msg): return msg
        case .error(let msg): return msg
        }
    }

}
