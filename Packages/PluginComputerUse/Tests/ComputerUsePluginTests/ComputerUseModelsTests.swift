import CoreGraphics
import Foundation
import Testing
@testable import ComputerUsePlugin

@Test func observationMapsImageCoordinatesIntoWindowCoordinates() {
    let observation = makeObservation(imageWidth: 800, imageHeight: 400)

    #expect(observation.screenPoint(imageX: 400, imageY: 200) == CGPoint(x: 120, y: 110))
    #expect(observation.screenPoint(imageX: 800, imageY: 400) == CGPoint(x: 220, y: 160))
}

@Test func observationFallsBackToWindowOriginForInvalidImageDimensions() {
    #expect(makeObservation(imageWidth: 0, imageHeight: 400).screenPoint(imageX: 10, imageY: 20) == CGPoint(x: 20, y: 60))
    #expect(makeObservation(imageWidth: 800, imageHeight: -1).screenPoint(imageX: 10, imageY: 20) == CGPoint(x: 20, y: 60))
}

@Test func actionsReportWhetherTheyChangeApplicationState() {
    let readOnlyActions: [ComputerUseAction] = [.screenshot, .move(x: 0, y: 0), .wait(milliseconds: 0)]
    let stateChangingActions: [ComputerUseAction] = [
        .click(x: 0, y: 0, button: .left, count: 1),
        .drag(path: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]),
        .scroll(x: 0, y: 0, deltaX: 0, deltaY: 1),
        .type("text"),
        .keypress(["A"]),
    ]

    #expect(readOnlyActions.allSatisfy { !$0.changesState })
    #expect(stateChangingActions.allSatisfy { $0.changesState })
}

@Test func windowSelectionMatchesApplicationAndTitleCaseInsensitively() {
    let windows = [
        makeWindow(id: 1, bundleIdentifier: "com.example.editor", applicationName: "Editor Pro", title: "Project One"),
        makeWindow(id: 2, bundleIdentifier: "com.example.browser", applicationName: "Web Browser", title: "Documentation"),
    ]

    #expect(ComputerUseWindowProvider.select(
        from: windows,
        application: "  EDITOR ",
        windowTitle: "project",
        frontmostBundleIdentifier: nil
    )?.id == 1)
    #expect(ComputerUseWindowProvider.select(
        from: windows,
        application: "com.example.browser",
        windowTitle: "DOC",
        frontmostBundleIdentifier: nil
    )?.id == 2)
    #expect(ComputerUseWindowProvider.select(
        from: windows,
        application: "missing",
        windowTitle: nil,
        frontmostBundleIdentifier: nil
    ) == nil)
}

@Test func blankWindowFiltersUseTheFrontmostApplication() {
    let windows = [
        makeWindow(id: 1, bundleIdentifier: "com.example.editor", applicationName: "Editor", title: "Project"),
        makeWindow(id: 2, bundleIdentifier: "com.example.browser", applicationName: "Browser", title: "Page"),
    ]

    #expect(ComputerUseWindowProvider.select(
        from: windows,
        application: " \n ",
        windowTitle: "  ",
        frontmostBundleIdentifier: "com.example.browser"
    )?.id == 2)
}

@Test func computerUseErrorsProvideReadableLocalizedDescriptions() {
    let errors: [ComputerUseError] = [
        .screenRecordingPermissionRequired,
        .accessibilityPermissionRequired,
        .noMatchingWindow,
        .applicationNotAllowed("Editor"),
        .observationNotFound,
        .staleObservation,
        .invalidArguments("bad coordinates"),
        .captureFailed,
        .eventCreationFailed,
        .secureInputBlocked,
        .visionModelRequired,
    ]

    #expect(errors.allSatisfy { error in
        guard let description = error.errorDescription else { return false }
        return !description.isEmpty
    })
    #expect(ComputerUseError.applicationNotAllowed("Editor").errorDescription?.contains("Editor") == true)
    #expect(ComputerUseError.invalidArguments("bad coordinates").errorDescription?.contains("bad coordinates") == true)
}

private func makeObservation(imageWidth: Int, imageHeight: Int) -> ComputerUseObservation {
    ComputerUseObservation(
        window: ComputerUseWindow(
            id: 1,
            processIdentifier: 2,
            bundleIdentifier: "test.bundle",
            applicationName: "Test App",
            windowTitle: "Main",
            frame: CGRect(x: 20, y: 60, width: 200, height: 100)
        ),
        imageWidth: imageWidth,
        imageHeight: imageHeight
    )
}

private func makeWindow(id: UInt32, bundleIdentifier: String, applicationName: String, title: String) -> ComputerUseWindow {
    ComputerUseWindow(
        id: id,
        processIdentifier: 2,
        bundleIdentifier: bundleIdentifier,
        applicationName: applicationName,
        windowTitle: title,
        frame: CGRect(x: 0, y: 0, width: 200, height: 100)
    )
}
