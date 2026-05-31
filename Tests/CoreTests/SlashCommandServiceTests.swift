#if canImport(XCTest)
import XCTest
@testable import Lumi

final class SlashCommandServiceTests: XCTestCase {
    func testHelpAliasesAreRecognizedAsSlashCommands() async {
        let service = SlashCommandService()
        let recognizesCommands = await service.isSlashCommand("/commands")
        let recognizesCmd = await service.isSlashCommand("/cmd")

        XCTAssertTrue(recognizesCommands)
        XCTAssertTrue(recognizesCmd)
    }

    func testHelpAliasesReturnCommandList() async {
        let service = SlashCommandService()

        let commandsResult = await service.handle(input: "/commands")
        let cmdResult = await service.handle(input: "/cmd")

        guard case .systemMessage(let commandsMessage) = commandsResult else {
            return XCTFail("Expected /commands to return command list, got \(commandsResult)")
        }
        guard case .systemMessage(let cmdMessage) = cmdResult else {
            return XCTFail("Expected /cmd to return command list, got \(cmdResult)")
        }

        XCTAssertTrue(commandsMessage.contains("/commands"))
        XCTAssertTrue(cmdMessage.contains("/cmd"))
    }

    func testHelpAliasSuggestionsAreAvailable() async {
        let service = SlashCommandService()

        let suggestions = await service.getSuggestions(for: "/cmd")

        XCTAssertTrue(suggestions.contains { $0.name == "/cmd" })
    }
}
#endif
