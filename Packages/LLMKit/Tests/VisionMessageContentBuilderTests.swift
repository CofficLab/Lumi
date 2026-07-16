import XCTest
@testable import LLMKit

final class VisionMessageContentBuilderTests: XCTestCase {
    func testAnthropicBlocksIncludeTextAndImage() {
        let image = MessageImage(data: Data([0x01, 0x02]), mimeType: "image/png")
        let blocks = VisionMessageContentBuilder.anthropicBlocks(text: "describe this", images: [image])

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0]["type"] as? String, "text")
        XCTAssertEqual(blocks[1]["type"] as? String, "image")

        let source = blocks[1]["source"] as? [String: Any]
        XCTAssertEqual(source?["type"] as? String, "base64")
        XCTAssertEqual(source?["media_type"] as? String, "image/png")
        XCTAssertEqual(source?["data"] as? String, "AQI=")
    }

    func testOpenAIContentUsesImageURLDataScheme() {
        let image = MessageImage(data: Data([0x01]), mimeType: "image/jpeg")
        let content = VisionMessageContentBuilder.openAIContent(text: "look", images: [image]) as? [[String: Any]]

        XCTAssertEqual(content?.count, 2)
        XCTAssertEqual(content?[1]["type"] as? String, "image_url")
        let imageURL = content?[1]["image_url"] as? [String: String]
        XCTAssertEqual(imageURL?["url"], "data:image/jpeg;base64,AQ==")
    }

    func testOpenAIContentReturnsPlainTextWhenNoImages() {
        let content = VisionMessageContentBuilder.openAIContent(text: "hello", images: [])
        XCTAssertEqual(content as? String, "hello")
    }
}
