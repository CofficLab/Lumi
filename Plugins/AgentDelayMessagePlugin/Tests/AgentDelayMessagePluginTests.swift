import Foundation
import LumiCoreKit
import Testing
@testable import AgentDelayMessagePlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func delayMessageSchemaDeclaresBoundedSeconds() throws {
    let schema = DelayMessageTool().inputSchema

    guard case .object(let keys) = schema else {
        Issue.record("schema should be an object")
        return
    }
    guard case .object(let properties) = keys["properties"],
          case .object(let secondsProps) = properties["seconds"] else {
        Issue.record("schema should declare seconds property")
        return
    }

    if case .string(let type) = secondsProps["type"] {
        #expect(type == "number")
    } else {
        Issue.record("seconds type missing")
    }
    if case .double(let minimum) = secondsProps["minimum"] {
        #expect(minimum == DelayMessageTool.minDelaySeconds)
    } else {
        Issue.record("seconds minimum missing")
    }
    if case .double(let maximum) = secondsProps["maximum"] {
        #expect(maximum == DelayMessageTool.maxDelaySeconds)
    } else {
        Issue.record("seconds maximum missing")
    }
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
