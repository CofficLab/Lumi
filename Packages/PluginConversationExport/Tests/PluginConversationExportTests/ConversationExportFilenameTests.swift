import Foundation
import Testing
@testable import PluginConversationExport

/// 回归 #513：导出建议文件名必须按最终 UTF-8 字节长度（含日期/扩展名）截断，
/// 多字节标题（如 emoji）不得超过 APFS 单组件 255 字节上限，且截断不切断字素簇。
@MainActor
struct ConversationExportFilenameTests {

    private let apfsLimit = 255
    private let dateTail = "20231114-221320"

    private func makeSnapshot(title: String) -> ConversationExportSnapshot {
        ConversationExportSnapshot(
            conversationID: UUID(),
            title: title,
            createdAt: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            language: nil,
            messages: [],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func filename(title: String, mode: ConversationExportMode = .debug) -> String {
        ConversationHTMLExporter.export(makeSnapshot(title: title), mode: mode).suggestedFilename
    }

    @Test("多字节标题的最终文件名不得超过 APFS 255 字节上限")
    func emojiTitleStaysWithinAPFSByteLimit() {
        // 64 个 🙂 = 256 UTF-8 字节，仅标题就已超 255；旧实现按字符 prefix(80) 不截断。
        let title = String(repeating: "🙂", count: 64)
        let name = filename(title: title)
        #expect(name.utf8.count <= apfsLimit)
        #expect(name.hasSuffix("-\(dateTail).html"))
        // 截断后仍由完整的 🙂 组成，未切断字符。
        let component = String(name.dropLast("-\(dateTail).html".count))
        #expect(!component.isEmpty)
        #expect(component.allSatisfy { $0 == "🙂" })
    }

    @Test("share 模式含 -share 后缀时文件名仍不得超过字节上限")
    func shareModeEmojiTitleStaysWithinByteLimit() {
        let title = String(repeating: "🙂", count: 64)
        let name = filename(title: title, mode: .share)
        #expect(name.utf8.count <= apfsLimit)
        #expect(name.hasSuffix("-share-\(dateTail).html"))
    }

    @Test("截断不得切断多标量字素簇（keycap emoji）")
    func truncationKeepsGraphemeClustersIntact() {
        // 1️⃣ 是 1 个字素簇 / 3 个标量 / 7 字节，且不含 ZWJ，能完整通过文件名清洗。
        // 预算 255-21=234 字节，floor(234/7)=33 个完整字素簇（231 字节）。
        // 若按标量而非字素簇截断，会多塞进一个孤立的 "1"（34 个字素簇），故本用例可区分二者。
        let keycap = "1️⃣"
        let title = String(repeating: keycap, count: 60)
        let name = filename(title: title)
        #expect(name.utf8.count <= apfsLimit)
        let tail = "-\(dateTail).html"
        #expect(name.hasSuffix(tail))
        let component = String(name.dropLast(tail.count))
        #expect(component.count == 33)
        #expect(component.utf8.count == 231)
        #expect(component.allSatisfy { String($0) == keycap })
    }

    @Test("短 Unicode 标题文件名保持不变")
    func shortUnicodeTitleFilenameUnchanged() {
        let name = filename(title: "设计 <讨论>")
        #expect(name == "设计-讨论-\(dateTail).html")
        #expect(name.utf8.count <= apfsLimit)
    }

    @Test("空标题回退到 Lumi-Conversation 且不超过字节上限")
    func emptyTitleFallsBackWithinLimit() {
        let name = filename(title: "   ")
        #expect(name == "Lumi-Conversation-\(dateTail).html")
        #expect(name.utf8.count <= apfsLimit)
    }

    @Test("长 ASCII 标题仍保留 80 字符上限且不超字节预算")
    func longASCIITitleKeepsCharacterCap() {
        let name = filename(title: String(repeating: "a", count: 200))
        let tail = "-\(dateTail).html"
        #expect(name.hasSuffix(tail))
        let component = String(name.dropLast(tail.count))
        #expect(component.count == 80)
        #expect(name.utf8.count <= apfsLimit)
    }
}