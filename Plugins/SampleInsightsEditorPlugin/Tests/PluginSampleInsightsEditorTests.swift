import Testing
@testable import PluginSampleInsightsEditor

@MainActor
@Test func packageLoads() async throws {
    #expect(SampleInsightsPanelContributor().id == "sample.insights.panel")
}

@Test func markerCounterOnlyCountsCommentMarkers() {
    let content = """
    let todoValue = "not a marker"
    let message = "TODO: user-facing text"
    // TODO: wire action
    /* FIXME: handle failure */
    """

    let summary = SampleInsightsMarkerCounter.countMarkers(in: content)

    #expect(summary.todo == 1)
    #expect(summary.fixme == 1)
}

@Test func markerCounterDoesNotCountMarkersInsideLongerWords() {
    let content = """
    // notodo should not count
    // TODO(later): count this
    // prefixFIXME should not count
    """

    let summary = SampleInsightsMarkerCounter.countMarkers(in: content)

    #expect(summary.todo == 1)
    #expect(summary.fixme == 0)
}
