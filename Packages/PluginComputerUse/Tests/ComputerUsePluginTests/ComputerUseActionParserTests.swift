import CoreGraphics
import Foundation
import Testing
@testable import ComputerUsePlugin

@Test func parserSupportsAllActionsAndAppliesDefaults() throws {
    let actions = try ComputerUseActionParser.parse([
        ["type": "SCREENSHOT"],
        ["type": "click", "x": 10, "y": 20],
        ["type": "double_click", "x": 11.5, "y": 21, "button": "right"],
        ["type": "move", "x": 12, "y": 22],
        ["type": "drag", "path": [["x": 1, "y": 2], ["x": 3, "y": 4]]],
        ["type": "scroll", "x": 5, "y": 6, "scroll_x": -3, "scroll_y": 8],
        ["type": "type", "text": "hello"],
        ["type": "keypress", "keys": ["COMMAND", "S"]],
        ["type": "wait"],
    ])

    #expect(actions == [
        .screenshot,
        .click(x: 10, y: 20, button: .left, count: 1),
        .click(x: 11.5, y: 21, button: .right, count: 2),
        .move(x: 12, y: 22),
        .drag(path: [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)]),
        .scroll(x: 5, y: 6, deltaX: -3, deltaY: 8),
        .type("hello"),
        .keypress(["COMMAND", "S"]),
        .wait(milliseconds: 1_000),
    ])
}

@Test func parserAcceptsExactlyTwentyActions() throws {
    let actions = try ComputerUseActionParser.parse(Array(repeating: ["type": "screenshot"], count: 20))
    #expect(actions.count == 20)
}

@Test func parserEnforcesActionAndCoordinateRequirements() {
    expectInvalid(nil, "actions must be an array")
    expectInvalid("screenshot", "actions must be an array")
    expectInvalid([], "actions must not be empty")
    expectInvalid(Array(repeating: ["type": "screenshot"], count: 21), "a batch may contain at most 20 actions")
    expectInvalid([42], "every action requires a type")
    expectInvalid([["x": 1, "y": 2]], "every action requires a type")
    expectInvalid([["type": "fly"]], "unsupported action type: fly")
    expectInvalid([["type": "click", "x": true, "y": 2]], "action requires non-negative finite x and y")
    expectInvalid([["type": "move", "x": -1, "y": 2]], "action requires non-negative finite x and y")
    expectInvalid([["type": "move", "x": Double.infinity, "y": 2]], "action requires non-negative finite x and y")
}

@Test func parserValidatesDragPathAndBounds() throws {
    expectInvalid([["type": "drag"]], "drag requires path")
    expectInvalid([["type": "drag", "path": [1, 2]]], "drag path entries must contain x and y")
    expectInvalid([["type": "drag", "path": [["x": 1, "y": 2]]]], "drag path must contain 2...100 points")
    expectInvalid([["type": "drag", "path": Array(repeating: ["x": 1, "y": 2], count: 101)]], "drag path must contain 2...100 points")

    let path = Array(repeating: ["x": 1, "y": 2], count: 100)
    #expect(try ComputerUseActionParser.parse([["type": "drag", "path": path]]) == [.drag(path: Array(repeating: CGPoint(x: 1, y: 2), count: 100))])
}

@Test func parserValidatesTextAndKeypressLimits() throws {
    expectInvalid([["type": "type"]], "type requires text no larger than 20 KB")
    expectInvalid([["type": "type", "text": String(repeating: "🦀", count: 5_001)]], "type requires text no larger than 20 KB")
    expectInvalid([["type": "keypress", "keys": []]], "keypress requires 1...8 keys")
    expectInvalid([["type": "keypress", "keys": Array(repeating: "A", count: 9)]], "keypress requires 1...8 keys")

    let exactLimit = String(repeating: "🦀", count: 5_000)
    #expect(try ComputerUseActionParser.parse([["type": "type", "text": exactLimit]]) == [.type(exactLimit)])
    #expect(try ComputerUseActionParser.parse([["type": "keypress", "keys": Array(repeating: "A", count: 8)]]).count == 1)
}

@Test func parserClampsWaitDurationWithoutOverflowingIntegerConversion() throws {
    #expect(try ComputerUseActionParser.parse([["type": "wait", "milliseconds": -1]]) == [.wait(milliseconds: 0)])
    #expect(try ComputerUseActionParser.parse([["type": "wait", "milliseconds": 10_001]]) == [.wait(milliseconds: 10_000)])
    #expect(try ComputerUseActionParser.parse([["type": "wait", "milliseconds": 12.9]]) == [.wait(milliseconds: 12)])
    #expect(try ComputerUseActionParser.parse([["type": "wait", "milliseconds": 1e100]]) == [.wait(milliseconds: 10_000)])
    expectInvalid([["type": "wait", "milliseconds": Double.infinity]], "wait milliseconds must be finite")
}

private func expectInvalid(_ value: Any?, _ expectedMessage: String) {
    do {
        _ = try ComputerUseActionParser.parse(value)
        Issue.record("Expected invalid action arguments: \(expectedMessage)")
    } catch let error as ComputerUseError {
        #expect(error == .invalidArguments(expectedMessage))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
