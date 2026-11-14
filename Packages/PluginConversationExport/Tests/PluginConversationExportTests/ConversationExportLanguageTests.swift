import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationExport

/// 回归 #653：HTML 导出的 <html lang> 必须跟随对话回复语言，而非恒为 zh-CN。
@MainActor
struct ConversationExportLanguageTests {
    @Test("English conversation exports lang=en")
    func englishConversationDeclaresEn() throws {
        let html = try exportHTML(language: .english)
        #expect(html.contains("<html lang=\"en\">"))
        #expect(!html.contains("<html lang=\"zh-CN\">"))
    }

    @Test("Chinese conversation exports lang=zh-CN")
    func chineseConversationDeclaresZhCN() throws {
        let html = try exportHTML(language: .chinese)
        #expect(html.contains("<html lang=\"zh-CN\">"))
    }

    @Test("Unset language falls back to zh-CN")
    func unsetLanguageFallsBackToZhCN() throws {
        let html = try exportHTML(language: nil)
        #expect(html.contains("<html lang=\"zh-CN\">"))
    }

    @Test("htmlLanguage maps each language to its declaration")
    func htmlLanguageMapsEachLanguage() {
        #expect(ConversationHTMLExporter.htmlLanguage(for: .english) == "en")
        #expect(ConversationHTMLExporter.htmlLanguage(for: .chinese) == "zh-CN")
        #expect(ConversationHTMLExporter.htmlLanguage(for: nil) == "zh-CN")
    }

    private func exportHTML(language: ConversationLanguage?) throws -> String {
        let conversationID = UUID()
        let snapshot = ConversationExportSnapshot(
            conversationID: conversationID,
            title: "Language",
            createdAt: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            language: language,
            messages: [Message(conversationID: conversationID, role: .user, content: "Hello")],
            exportedAt: Date(timeIntervalSince1970: 0)
        )
        return try #require(String(data: ConversationHTMLExporter.export(snapshot).data, encoding: .utf8))
    }
}