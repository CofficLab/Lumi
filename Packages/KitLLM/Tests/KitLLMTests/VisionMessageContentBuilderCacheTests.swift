import Foundation
import Testing
@testable import KitLLM

/// 视觉内容构建器的缓存接入契约（Issue #1269）。
///
/// 关键要求：**请求体语义不能因为缓存而改变**。
/// 同一批图片重复构建出的内容块必须与直接编码的结果逐字节相同。
@Suite("VisionMessageContentBuilder 接入 Base64 缓存")
struct VisionMessageContentBuilderCacheTests {

    private func makeImage(byte: UInt8, count: Int = 2048) -> MessageImage {
        MessageImage(data: Data(repeating: byte, count: count), mimeType: "image/png")
    }

    // MARK: - Anthropic

    @Test("Anthropic 图片块内容与直接编码一致")
    func anthropicBlocksMatchDirectEncoding() {
        let image = makeImage(byte: 0x42)
        let blocks = VisionMessageContentBuilder.anthropicBlocks(text: "看图", images: [image])

        #expect(blocks.count == 2)
        #expect(blocks[0]["type"] as? String == "text")
        #expect(blocks[0]["text"] as? String == "看图")

        let source = blocks[1]["source"] as? [String: Any]
        #expect(blocks[1]["type"] as? String == "image")
        #expect(source?["type"] as? String == "base64")
        #expect(source?["media_type"] as? String == "image/png")
        #expect(source?["data"] as? String == image.data.base64EncodedString())
    }

    @Test("Anthropic 重复构建返回完全相同的内容块")
    func anthropicBlocksAreStableAcrossCalls() {
        let image = makeImage(byte: 0x33)

        let first = VisionMessageContentBuilder.anthropicBlocks(text: "t", images: [image])
        let second = VisionMessageContentBuilder.anthropicBlocks(text: "t", images: [image])

        #expect(first.count == second.count)
        for (left, right) in zip(first, second) {
            #expect(left["type"] as? String == right["type"] as? String)
            let leftSource = left["source"] as? [String: Any]
            let rightSource = right["source"] as? [String: Any]
            #expect(leftSource?["data"] as? String == rightSource?["data"] as? String)
        }
    }

    @Test("Anthropic 无图片时只产出文本块")
    func anthropicBlocksWithoutImages() {
        let blocks = VisionMessageContentBuilder.anthropicBlocks(text: "hello", images: [])

        #expect(blocks.count == 1)
        #expect(blocks[0]["type"] as? String == "text")
        #expect(blocks[0]["text"] as? String == "hello")
    }

    @Test("Anthropic 空文本时不产出空文本块")
    func anthropicBlocksSkipEmptyText() {
        let blocks = VisionMessageContentBuilder.anthropicBlocks(
            text: "",
            images: [makeImage(byte: 0x01)]
        )

        #expect(blocks.count == 1)
        #expect(blocks[0]["type"] as? String == "image")
    }

    // MARK: - OpenAI

    @Test("OpenAI 图片 data URL 与直接编码一致")
    func openAIContentMatchesDirectEncoding() {
        let image = makeImage(byte: 0x77)
        let content = VisionMessageContentBuilder.openAIContent(text: "看图", images: [image])

        guard let parts = content as? [[String: Any]] else {
            Issue.record("预期为内容数组")
            return
        }
        #expect(parts.count == 2)
        #expect(parts[0]["type"] as? String == "text")

        let imageURL = parts[1]["image_url"] as? [String: Any]
        let expected = "data:image/png;base64,\(image.data.base64EncodedString())"
        #expect(imageURL?["url"] as? String == expected)
    }

    @Test("OpenAI 无图片时直接返回文本")
    func openAIContentWithoutImagesReturnsText() {
        let content = VisionMessageContentBuilder.openAIContent(text: "plain", images: [])

        #expect(content as? String == "plain")
    }

    @Test("OpenAI 重复构建返回完全相同的 data URL")
    func openAIContentIsStableAcrossCalls() {
        let image = makeImage(byte: 0x55)

        let first = VisionMessageContentBuilder.openAIContent(text: "t", images: [image])
        let second = VisionMessageContentBuilder.openAIContent(text: "t", images: [image])

        guard let left = first as? [[String: Any]],
              let right = second as? [[String: Any]] else {
            Issue.record("预期为内容数组")
            return
        }
        let leftURL = (left[1]["image_url"] as? [String: Any])?["url"] as? String
        let rightURL = (right[1]["image_url"] as? [String: Any])?["url"] as? String
        #expect(leftURL == rightURL)
    }

    @Test("不同图片产生不同的 data URL")
    func differentImagesProduceDifferentURLs() {
        let first = VisionMessageContentBuilder.openAIContent(
            text: "",
            images: [makeImage(byte: 0x01)]
        )
        let second = VisionMessageContentBuilder.openAIContent(
            text: "",
            images: [makeImage(byte: 0x02)]
        )

        guard let left = first as? [[String: Any]],
              let right = second as? [[String: Any]] else {
            Issue.record("预期为内容数组")
            return
        }
        let leftURL = (left[0]["image_url"] as? [String: Any])?["url"] as? String
        let rightURL = (right[0]["image_url"] as? [String: Any])?["url"] as? String
        #expect(leftURL != rightURL)
    }

    // MARK: - 性能回归

    @Test("重复构建同一批图片的耗时显著低于每次重新编码")
    func repeatedBuildIsCheaperThanFirstBuild() {
        let images = (0..<4).map { index in
            MessageImage(
                data: Data(repeating: UInt8(index), count: 800_000),
                mimeType: "image/png"
            )
        }

        // 预热：把这批图片放进缓存。
        _ = VisionMessageContentBuilder.openAIContent(text: "", images: images)

        let iterations = 20

        // 度量口径只覆盖「产出 data URL」这一段。
        //
        // 不能直接拿 `openAIContent` 的返回值比：`[[String: Any]]` 装进
        // `Any` existential 会触发一次装箱拷贝（实测数毫秒），那一项开销与
        // 图片编码无关，会把结论淹没。
        let firstStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = images.map { "data:image/png;base64,\($0.data.base64EncodedString())" }
        }
        let firstElapsed = DispatchTime.now().uptimeNanoseconds - firstStart

        let cachedStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = VisionMessageContentBuilder.openAIContent(text: "", images: images)
        }
        let cachedElapsed = DispatchTime.now().uptimeNanoseconds - cachedStart

        // 命中缓存必须明显更快；放宽到「至少快 2 倍」以稳定抓住回归。
        #expect(cachedElapsed * 2 < firstElapsed)
    }

    @Test("统计编码长度不得使用 O(n) 的 String.count")
    func encodedLengthUsesConstantTimeCount() throws {
        // `String.count` 是 O(n) 的 grapheme cluster 遍历；`utf8.count` 是 O(1)。
        // 构建器为了打日志统计编码长度，若用 `count`，每次构建都要多扫一遍
        // 整个 base64 字符串——比编码本身还贵。
        //
        // 这里用**源码级断言**而不是计时断言：计时在并行测试下波动极大，
        // 无法稳定区分「O(1)」与「O(n)」；而「是否用了 `.count`」是确定性事实。
        let sourceURL = try #require(
            Self.sourceURL(for: "VisionMessageContentBuilder"),
            "应能找到构建器源码"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        // 只检查统计编码长度的那几行：`.count` 不能出现在 base64 字符串上。
        //
        // 注意 `utf8.count` 本身也含 `.count` 子串，因此要排除它——
        // 判定标准是「有没有直接对字符串取 `.count`」。
        var checkedLines = 0
        for line in source.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("encodedChars +=") else { continue }
            checkedLines += 1

            // 去掉 `utf8.count` 后，剩下的 `.count` 就是 O(n) 的那种。
            let withoutUTF8 = trimmed.replacingOccurrences(of: "utf8.count", with: "")
            #expect(
                !withoutUTF8.contains(".count"),
                "统计 base64 长度必须用 O(1) 的 utf8.count，不能用 O(n) 的 count：\(trimmed)"
            )
        }
        // 两处统计点（Anthropic 与 OpenAI）都要被覆盖到。
        #expect(checkedLines >= 2, "应找到两处编码长度统计点，实际 \(checkedLines)")
    }

    /// 定位包内源码文件。
    ///
    /// SPM 的测试产物不含源码，`Bundle.module` 指向资源 bundle，因此按
    /// 仓库布局从包目录往上找 `Sources/<Package>/Adapters/<name>.swift`。
    private static func sourceURL(for fileName: String) -> URL? {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // KitLLMTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // KitLLM（包根）
        let candidates = [
            directory.appendingPathComponent("Sources/KitLLM/Adapters/\(fileName).swift"),
            directory.appendingPathComponent("Sources/KitLLM/Support/\(fileName).swift"),
            directory.appendingPathComponent("Sources/KitLLM/Base/\(fileName).swift"),
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
