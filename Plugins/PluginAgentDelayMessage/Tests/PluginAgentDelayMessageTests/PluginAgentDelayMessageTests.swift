import Foundation
import Testing
@testable import PluginAgentDelayMessage

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func delayMessageSchemaDeclaresBoundedSeconds() throws {
    let schema = DelayMessageTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])

    #expect(properties["seconds"]?["type"] as? String == "number")
    #expect(properties["seconds"]?["minimum"] as? TimeInterval == DelayMessageTool.minDelaySeconds)
    #expect(properties["seconds"]?["maximum"] as? TimeInterval == DelayMessageTool.maxDelaySeconds)
}

@Test func delaySecondsAreNormalizedAcrossArgumentTypes() {
    #expect(DelayMessageTool.normalizedDelaySeconds(nil) == DelayMessageTool.defaultDelaySeconds)
    #expect(DelayMessageTool.normalizedDelaySeconds(-10) == DelayMessageTool.minDelaySeconds)
    #expect(DelayMessageTool.normalizedDelaySeconds(60) == 60)
    #expect(DelayMessageTool.normalizedDelaySeconds(2.5) == 2.5)
    #expect(DelayMessageTool.normalizedDelaySeconds("7.5") == 7.5)
    #expect(DelayMessageTool.normalizedDelaySeconds(9_999) == DelayMessageTool.maxDelaySeconds)
    #expect(DelayMessageTool.normalizedDelaySeconds(Double.nan) == DelayMessageTool.defaultDelaySeconds)
}
