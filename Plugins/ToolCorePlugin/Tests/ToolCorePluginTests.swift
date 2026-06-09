import Testing
@testable import ToolCorePlugin

@Test func packageLoads() async throws {
    let tools = await ToolCorePlugin.agentTools(context: .init(activeSectionID: "test", activeSectionTitle: "Test"))
    #expect(tools.map(\.name).sorted() == ["edit_file", "ls", "read_file", "run_command", "write_file"])
}
