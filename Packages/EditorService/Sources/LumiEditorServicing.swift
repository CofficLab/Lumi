import Foundation
import KernelLumi

@MainActor
public protocol LumiEditorServicing {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
}
