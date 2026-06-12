import Foundation

@MainActor
public protocol LumiEditorServicing: AnyObject {
    var editorService: EditorService { get }
    var extensionRegistry: EditorExtensionRegistry { get }
    var currentProjectPathProvider: (() -> String)? { get set }
    func reinstallExtensions()
}
