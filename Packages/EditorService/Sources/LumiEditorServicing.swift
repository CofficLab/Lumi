import Foundation
import LumiCoreKit

@MainActor
public protocol LumiEditorServicing: AbstractEditorServicing {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
}
