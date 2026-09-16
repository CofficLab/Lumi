import Carbon.HIToolbox
import CoreGraphics
import Foundation
import Testing
@testable import ComputerUsePlugin

@Test func inputExecutorMapsInBoundsImageCoordinates() throws {
    let observation = makeInputObservation(width: 100, height: 50)
    #expect(try ComputerUseInputExecutor.screenPoint(x: 0, y: 0, observation: observation) == CGPoint(x: 10, y: 20))
    #expect(try ComputerUseInputExecutor.screenPoint(x: 100, y: 50, observation: observation) == CGPoint(x: 210, y: 120))
}

@Test func inputExecutorRejectsInvalidCoordinatesWithoutIntegerOverflow() {
    let observation = makeInputObservation(width: 100, height: 50)
    expectInvalidCoordinate(-1, 0, observation: observation)
    expectInvalidCoordinate(101, 0, observation: observation)
    expectInvalidCoordinate(Double.infinity, 0, observation: observation)
    expectInvalidCoordinate(0, .nan, observation: observation)
}

@Test func keyCodeRecognizesLettersDigitsAndCommonKeys() {
    #expect(ComputerUseInputExecutor.keyCode(for: "A") == CGKeyCode(kVK_ANSI_A))
    #expect(ComputerUseInputExecutor.keyCode(for: "9") == CGKeyCode(kVK_ANSI_9))
    #expect(ComputerUseInputExecutor.keyCode(for: "ARROWLEFT") == CGKeyCode(kVK_LeftArrow))
    #expect(ComputerUseInputExecutor.keyCode(for: "RETURN") == CGKeyCode(kVK_Return))
    #expect(ComputerUseInputExecutor.keyCode(for: "unknown") == nil)
}

@Test func screenshotAndZeroWaitActionsDoNotPostInputEvents() async throws {
    let observation = makeInputObservation(width: 100, height: 50)
    try await ComputerUseInputExecutor.execute(.screenshot, observation: observation)
    try await ComputerUseInputExecutor.execute(.wait(milliseconds: 0), observation: observation)
}

private func expectInvalidCoordinate(
    _ x: Double,
    _ y: Double,
    observation: ComputerUseObservation,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    do {
        _ = try ComputerUseInputExecutor.screenPoint(x: x, y: y, observation: observation)
        Issue.record("Expected coordinate to be rejected", sourceLocation: sourceLocation)
    } catch let error as ComputerUseError {
        #expect(
            error == .invalidArguments("coordinate (\(x), \(y)) is outside 100x50"),
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record("Unexpected error: \(error)", sourceLocation: sourceLocation)
    }
}

private func makeInputObservation(width: Int, height: Int) -> ComputerUseObservation {
    ComputerUseObservation(
        window: ComputerUseWindow(
            id: 1,
            processIdentifier: 2,
            bundleIdentifier: "test.bundle",
            applicationName: "Test App",
            windowTitle: "Main",
            frame: CGRect(x: 10, y: 20, width: 200, height: 100)
        ),
        imageWidth: width,
        imageHeight: height
    )
}
