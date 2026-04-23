import Foundation
import LanguageServerProtocol

/// 编辑器侧 LSP 客户端抽象
/// 作为 Editor 与具体 LSP 实现之间的解耦边界，便于后续独立 Plugin 化。
@MainActor
public protocol EditorLSPClient: AnyObject {
    func requestCompletion(line: Int, character: Int) async -> [CompletionItem]
    func requestHoverRaw(line: Int, character: Int) async -> Hover?
    func requestDefinition(line: Int, character: Int) async -> Location?
    func requestDeclaration(line: Int, character: Int) async -> Location?
    func requestTypeDefinition(line: Int, character: Int) async -> Location?
    func requestImplementation(line: Int, character: Int) async -> Location?
    func completionTriggerCharacters() -> Set<String>
}
