import Foundation
import EditorContracts

@MainActor
public protocol LumiEditorServicing {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
}
