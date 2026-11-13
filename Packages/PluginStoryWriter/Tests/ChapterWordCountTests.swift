import Foundation
import Testing

@testable import StoryWriterPlugin

/// 章节字数统计的缓存维护（见 issue #1295）。
///
/// 章节编辑页的 body 会在每次按键后重跑；原先 `wordCount` 是每次求值都
/// 重新遍历全文的计算属性，因此每敲一个字都要重数一遍整章。
struct ChapterWordCountTests {

    @Test("字数统计与逐字符统计语义一致")
    func wordCountMatchesCharacterCount() {
        let samples = [
            "",
            "a",
            "你好 world\n",
            "  \n\t ",
            "第一行\n第二行\n第三行",
            "trailing spaces   "
        ]

        for sample in samples {
            let expected = sample.filter { !$0.isWhitespace }.count
            let chapter = Chapter(storyID: UUID(), title: "T", content: sample)
            #expect(chapter.wordCount == expected, "sample: \(sample.debugDescription)")
        }
    }

    @Test("修改正文后字数同步更新")
    func wordCountUpdatesWithContent() {
        var chapter = Chapter(storyID: UUID(), title: "T", content: "abc")
        #expect(chapter.wordCount == 3)

        chapter.content = "abc def"
        #expect(chapter.wordCount == 6)

        chapter.content = ""
        #expect(chapter.wordCount == 0)

        chapter.content = "你好"
        #expect(chapter.wordCount == 2)
    }

    @Test("解码后字数正确")
    func wordCountIsRecomputedAfterDecoding() throws {
        let chapter = Chapter(storyID: UUID(), title: "T", content: "你好 world\n")
        let data = try JSONEncoder().encode(chapter)
        let decoded = try JSONDecoder().decode(Chapter.self, from: data)

        #expect(decoded.wordCount == 7)
        #expect(decoded.content == chapter.content)
    }

    @Test("编码不含派生的字数字段")
    func encodedPayloadOmitsWordCount() throws {
        let chapter = Chapter(storyID: UUID(), title: "T", content: "abc")
        let data = try JSONEncoder().encode(chapter)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(object?["wordCount"] == nil)
        #expect(object?["content"] != nil)
    }

    @Test("解码旧文件（无字数字段）仍能得到正确字数")
    func decodingLegacyPayloadWithoutWordCountWorks() throws {
        let storyID = UUID()
        let payload = """
        {
          "id": "\(UUID().uuidString)",
          "storyID": "\(storyID.uuidString)",
          "title": "Legacy",
          "content": "你好 world",
          "status": "draft",
          "targetWordCount": 0,
          "createdAt": 0,
          "updatedAt": 0
        }
        """
        let decoded = try JSONDecoder().decode(Chapter.self, from: Data(payload.utf8))

        #expect(decoded.wordCount == 7)
    }
}
