import Foundation

@MainActor
public protocol LumiEditorServicing: AnyObject {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
    func reinstallExtensions()
}
