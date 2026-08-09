import CoreGraphics
import Foundation

public struct ComputerUseWindow: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let processIdentifier: pid_t
    public let bundleIdentifier: String
    public let applicationName: String
    public let windowTitle: String
    public let frame: CGRect

    public init(
        id: CGWindowID,
        processIdentifier: pid_t,
        bundleIdentifier: String,
        applicationName: String,
        windowTitle: String,
        frame: CGRect
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.frame = frame
    }
}

public struct ComputerUseObservation: Equatable, Sendable {
    public let id: UUID
    public let window: ComputerUseWindow
    public let imageWidth: Int
    public let imageHeight: Int
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        window: ComputerUseWindow,
        imageWidth: Int,
        imageHeight: Int,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.window = window
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.capturedAt = capturedAt
    }

    func screenPoint(imageX: Double, imageY: Double) -> CGPoint {
        guard imageWidth > 0, imageHeight > 0 else { return window.frame.origin }
        return CGPoint(
            x: window.frame.minX + CGFloat(imageX / Double(imageWidth)) * window.frame.width,
            y: window.frame.minY + CGFloat(imageY / Double(imageHeight)) * window.frame.height
        )
    }
}

enum ComputerUseAction: Equatable, Sendable {
    case screenshot
    case click(x: Double, y: Double, button: ComputerMouseButton, count: Int)
    case move(x: Double, y: Double)
    case drag(path: [CGPoint])
    case scroll(x: Double, y: Double, deltaX: Double, deltaY: Double)
    case type(String)
    case keypress([String])
    case wait(milliseconds: Int)

    var changesState: Bool {
        switch self {
        case .screenshot, .move, .wait: false
        case .click, .drag, .scroll, .type, .keypress: true
        }
    }
}

enum ComputerMouseButton: String, Equatable, Sendable {
    case left
    case right
    case center
}

enum ComputerUseError: LocalizedError, Equatable {
    case screenRecordingPermissionRequired
    case accessibilityPermissionRequired
    case noMatchingWindow
    case applicationNotAllowed(String)
    case observationNotFound
    case staleObservation
    case invalidArguments(String)
    case captureFailed
    case eventCreationFailed
    case secureInputBlocked
    case visionModelRequired

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionRequired:
            "Screen Recording permission is required. Open Lumi Settings > Computer Use."
        case .accessibilityPermissionRequired:
            "Accessibility permission is required. Open Lumi Settings > Computer Use."
        case .noMatchingWindow:
            "No matching on-screen application window was found."
        case .applicationNotAllowed(let name):
            "Control of \(name) is not allowed. Add it under Lumi Settings > Computer Use."
        case .observationNotFound:
            "The observation does not exist. Call computer_observe again."
        case .staleObservation:
            "The target window changed since the screenshot was captured. Call computer_observe again."
        case .invalidArguments(let message):
            "Invalid Computer Use arguments: \(message)"
        case .captureFailed:
            "The target window could not be captured."
        case .eventCreationFailed:
            "A macOS input event could not be created."
        case .secureInputBlocked:
            "Typing into a secure text field is blocked."
        case .visionModelRequired:
            "Computer Use requires a model that supports both vision and tools. Select a compatible model and try again."
        }
    }
}
