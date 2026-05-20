import Foundation
import LumiPreviewKit
import Testing

@Suite("PreviewError")
struct PreviewErrorTests {
    @Test("2.6 PreviewError cases are Equatable")
    func previewErrorEquality() {
        let cases: [LumiPreviewFacade.PreviewError] = [
            .targetNotFound(file: "/tmp/A.swift"),
            .unsupportedProjectType(path: "/tmp"),
            .compilationFailed(message: "failed"),
            .buildProductNotFound,
            .hostLaunchFailed(message: "launch"),
            .runtimeCrashed(message: "crash"),
            .timedOut(seconds: 3),
            .missingDependency(description: "env object"),
        ]

        for error in cases {
            #expect(error == error)
        }

        #expect(LumiPreviewFacade.PreviewError.targetNotFound(file: "a") != .targetNotFound(file: "b"))
        #expect(LumiPreviewFacade.PreviewError.compilationFailed(message: "a") != .compilationFailed(message: "b"))
        #expect(LumiPreviewFacade.PreviewError.timedOut(seconds: 1) != .timedOut(seconds: 2))
    }
}
