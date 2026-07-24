import Foundation
import LumiKernel

@MainActor
public protocol LumiEditorServicing {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
}
