import Testing
@testable import ToolCorePlugin

@Test func packageLoads() async throws {
    let tools = await ToolCorePlugin.agentTools(context: .init(activeSectionID: "test", activeSectionTitle: "Test"))
    #expect(tools.map(\.name).sorted() == ["ls", "read_file"])
}
