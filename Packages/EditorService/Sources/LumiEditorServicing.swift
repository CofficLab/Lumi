import Foundation
import LumiKernel

@MainActor
public protocol LumiEditorServicing: AbstractEditorServicing {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
}
