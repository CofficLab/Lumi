@testable import EditorSwiftPlugin
import EditorService
import Foundation
import Testing
import XcodeKit

@MainActor
@Test func buildContextStatusDescriptionMapsKnownStates() {
    let unknown = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(.unknown)
    #expect(!unknown.isEmpty)
    #expect(unknown == XcodeProjectStatusPresentation.localizedBuildContextStatusDescription("Unknown"))

    let resolving = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(.resolving)
    #expect(!resolving.isEmpty)
    #expect(resolving == XcodeProjectStatusPresentation.localizedBuildContextStatusDescription("Resolving build context..."))

    let available = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(
        .available(.init(buildServerJSONPath: "/tmp/buildServer.json", workspacePath: "/tmp/App.xcodeproj", scheme: "App"))
    )
    #expect(available.contains("App"))

    let unavailable = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription(.unavailable("missing tool"))
    #expect(unavailable.contains("missing tool"))
}

@MainActor
@Test func buildContextStatusDescriptionParsesBridgeText() {
    let parsed = XcodeProjectStatusPresentation.localizedBuildContextStatusDescription("Available (scheme: Lumi)")
    #expect(parsed.contains("Lumi"))
    #expect(
        XcodeProjectStatusPresentation.localizedBuildContextStatusDescription("Unavailable: xcode-build-server missing")
            .contains("xcode-build-server missing")
    )
    #expect(
        XcodeProjectStatusPresentation.localizedBuildContextStatusDescription("Not Initialized")
        == XcodeProjectStatusPresentation.localizedBuildContextStatusDescription("Not Initialized")
    )
}

@MainActor
@Test func semanticReasonLocalizationRewritesKnownIds() {
    let reason = XcodeSemanticAvailability.Reason(
        id: "file-not-in-target",
        severity: .warning,
        title: "raw",
        message: "Current file 'Feature.swift' is not in any target."
    )
    let localized = XcodeProjectStatusPresentation.localizedSemanticReason(reason)
    #expect(localized.title != "raw")
    #expect(localized.message.contains("Feature.swift"))
}

@MainActor
@Test func semanticReasonSchemeExcludesTargetsParsesMessage() {
    let reason = XcodeSemanticAvailability.Reason(
        id: "scheme-excludes-targets",
        severity: .warning,
        title: "raw",
        message: "Current scheme 'App' does not include WidgetExtension."
    )
    let localized = XcodeProjectStatusPresentation.localizedSemanticReason(reason)
    #expect(localized.message.contains("App"))
    #expect(localized.message.contains("WidgetExtension"))
}

@MainActor
@Test func extractSingleQuotedValue() {
    #expect(XcodeProjectStatusPresentation.extractSingleQuotedValue(from: "file 'MyFile.swift' missing") == "MyFile.swift")
    #expect(XcodeProjectStatusPresentation.extractSingleQuotedValue(from: "no quotes") == nil)
}

@MainActor
@Test func semanticStatusTextUsesBuildContextWhenNotIndexing() {
    let configReady = XcodeProjectStatusPresentation.semanticStatusText(
        indexingTask: nil,
        buildContextStatus: .available(
            .init(buildServerJSONPath: "/tmp", workspacePath: "/tmp", scheme: "App")
        ),
        semanticIndexStatus: .notStarted
    )
    #expect(configReady == XcodeProjectStatusPresentation.localizedSemanticIndexStatusText(for: .notStarted))

    let ready = XcodeProjectStatusPresentation.semanticStatusText(
        indexingTask: nil,
        buildContextStatus: .available(
            .init(buildServerJSONPath: "/tmp", workspacePath: "/tmp", scheme: "App")
        ),
        semanticIndexStatus: .ready
    )
    #expect(ready == XcodeProjectStatusPresentation.localizedSemanticIndexStatusText(for: .ready))

    let resolving = XcodeProjectStatusPresentation.semanticStatusText(indexingTask: nil, buildContextStatus: .resolving)
    #expect(resolving == XcodeProjectStatusPresentation.localizedSemanticStatusText(for: .resolving))
}

@MainActor
@Test func semanticStatusTextShowsProjectIndexingState() {
    let indexing = XcodeProjectStatusPresentation.semanticStatusText(
        indexingTask: nil,
        buildContextStatus: .available(
            .init(buildServerJSONPath: "/tmp", workspacePath: "/tmp", scheme: "App")
        ),
        semanticIndexStatus: .indexing
    )
    #expect(indexing == XcodeProjectStatusPresentation.localizedSemanticIndexStatusText(for: .indexing))
}

@MainActor
@Test func semanticStatusTextPrefersResolutionProgressWhileResolving() {
    let startedAt = Date(timeIntervalSinceReferenceDate: 100)
    let progress = BuildContextResolutionProgress(
        phase: .runningXcodebuildList,
        detail: "Lumi.xcodeproj",
        startedAt: startedAt
    )
    let text = XcodeProjectStatusPresentation.semanticStatusText(
        indexingTask: nil,
        buildContextStatus: .resolving,
        resolutionProgress: progress,
        now: Date(timeIntervalSinceReferenceDate: 103)
    )
    #expect(text.contains("xcodebuild"))
    #expect(text.contains("3s"))
}

@MainActor
@Test func semanticStatusTextShowsScanningFileDuringMembershipParsing() {
    let progress = BuildContextResolutionProgress(
        phase: .parsingProjectMembership,
        detail: "Lumi.xcodeproj",
        currentItem: "RootView.swift"
    )
    let text = XcodeProjectStatusPresentation.semanticStatusText(
        indexingTask: nil,
        buildContextStatus: .resolving,
        resolutionProgress: progress
    )
    #expect(text.contains("RootView.swift"))
}

@MainActor
@Test func semanticStatusDescriptionUsesBuildContextWhenNotIndexing() {
    let description = XcodeProjectStatusPresentation.semanticStatusDescription(
        indexingTask: nil,
        buildContextStatusDescription: "Unavailable: tool missing"
    )
    #expect(description.contains("tool missing"))
}

@MainActor
@Test func semanticStatusAppearanceMapsStates() {
    #expect(
        XcodeProjectStatusPresentation.semanticStatusAppearance(isIndexing: true, buildContextStatus: .unknown)
        == .indexing
    )
    #expect(
        XcodeProjectStatusPresentation.semanticStatusAppearance(isIndexing: false, buildContextStatus: .needsResync)
        == .needsResync
    )
}
