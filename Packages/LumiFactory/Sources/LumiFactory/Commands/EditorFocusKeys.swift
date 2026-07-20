import EditorService
import SwiftUI

/// FocusedValueKey for the active window's editor service.
///
/// Used by menu commands (`Commands`) to access the current window's `EditorService`
/// without relying on `@EnvironmentObject`, enabling focus-independent shortcuts
/// like ⌘S save.
struct ActiveEditorServiceKey: FocusedValueKey {
    typealias Value = EditorService
}

extension FocusedValues {
    /// The editor service of the currently active window (available when an editor
    /// within the window has focus).
    var activeEditorService: EditorService? {
        get { self[ActiveEditorServiceKey.self] }
        set { self[ActiveEditorServiceKey.self] = newValue }
    }
}
