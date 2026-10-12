import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Coordinate/key mapping only. Native input is emitted exclusively by NativeInputDriver.
enum ComputerUseInputExecutor {
    static func execute(_ action: ComputerUseAction, observation: ComputerUseObservation) async throws {
        switch action {
        case .screenshot: return
        case .wait(let milliseconds): try await Task.sleep(for: .milliseconds(milliseconds))
        default: throw ComputerUseError.invalidArguments("Native input requires a coordinator lease. Use computer_act.")
        }
    }

    static func screenPoint(
        x: Double,
        y: Double,
        observation: ComputerUseObservation
    ) throws -> CGPoint {
        guard x >= 0, y >= 0,
              x <= Double(observation.imageWidth),
              y <= Double(observation.imageHeight)
        else {
            throw ComputerUseError.invalidArguments(
                "coordinate (\(x), \(y)) is outside \(observation.imageWidth)x\(observation.imageHeight)"
            )
        }
        return observation.screenPoint(imageX: x, imageY: y)
    }

    static func keyCode(for key: String) -> CGKeyCode? {
        let letters: [String: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        ]
        if let code = letters[key] { return CGKeyCode(code) }
        let special: [String: Int] = [
            "RETURN": kVK_Return, "ENTER": kVK_Return, "TAB": kVK_Tab,
            "SPACE": kVK_Space, "ESC": kVK_Escape, "ESCAPE": kVK_Escape,
            "DELETE": kVK_ForwardDelete, "BACKSPACE": kVK_Delete,
            "LEFT": kVK_LeftArrow, "ARROWLEFT": kVK_LeftArrow,
            "RIGHT": kVK_RightArrow, "ARROWRIGHT": kVK_RightArrow,
            "UP": kVK_UpArrow, "ARROWUP": kVK_UpArrow,
            "DOWN": kVK_DownArrow, "ARROWDOWN": kVK_DownArrow,
            "HOME": kVK_Home, "END": kVK_End,
            "PAGEUP": kVK_PageUp, "PAGEDOWN": kVK_PageDown,
        ]
        return special[key].map(CGKeyCode.init)
    }
}
