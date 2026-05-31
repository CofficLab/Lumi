import Testing
@testable import PluginSampleDecorationEditor

@Test func packageLoads() async throws {
    #expect(SampleDecorationEditorPlugin.id == "SampleDecorationEditor")
    #expect(SampleDecorationEditorPlugin.displayName.isEmpty == false)
}

@Test func markerDetectorOnlyMatchesCommentMarkers() {
    #expect(SampleDecorationMarkerDetector.markers(in: "let todoValue = \"TODO text\"").isEmpty)
    #expect(SampleDecorationMarkerDetector.markers(in: "// TODO: finish this") == [.todo])
    #expect(SampleDecorationMarkerDetector.markers(in: "/* FIXME: handle failure */") == [.fixme])
}

@Test func markerDetectorDoesNotMatchInsideLongerWords() {
    #expect(SampleDecorationMarkerDetector.markers(in: "// notodo is not a marker").isEmpty)
    #expect(SampleDecorationMarkerDetector.markers(in: "// TODO(later): marker") == [.todo])
}
