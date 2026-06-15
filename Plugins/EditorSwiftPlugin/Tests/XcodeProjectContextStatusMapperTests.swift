@testable import EditorSwiftPlugin
import EditorService
import Testing

@Test func statusMapperRecognizesResyncAndResolving() {
    #expect(XcodeProjectContextStatusMapper.map(description: "Needs resync") == .needsResync)
    #expect(XcodeProjectContextStatusMapper.map(description: "Resolving build context...") == .resolving)
}

@Test func statusMapperRecognizesUnavailableAndAvailable() {
    if case .unavailable(let reason) = XcodeProjectContextStatusMapper.map(description: "Unavailable: tool missing") {
        #expect(reason == "tool missing")
    } else {
        Issue.record("Expected unavailable status")
    }

    if case .available(let description) = XcodeProjectContextStatusMapper.map(description: "Available (scheme: App)") {
        #expect(description?.contains("Available") == true)
    } else {
        Issue.record("Expected available status")
    }
}

@Test func statusMapperTreatsUnknownStatesAsUnknown() {
    #expect(XcodeProjectContextStatusMapper.map(description: "Unknown") == .unknown)
    #expect(XcodeProjectContextStatusMapper.map(description: "Not Initialized") == .unknown)
}
