import Foundation
import ProviderEditor

@MainActor
public protocol LumiEditorServicing {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
}
