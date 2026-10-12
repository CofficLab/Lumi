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
        case .screenshot, .wait: false
        case .click, .move, .drag, .scroll, .type, .keypress: true
        }
    }

    var requiresNativeInput: Bool { changesState }
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
            pluginLocalization.string("Screen Recording permission is required. Open Lumi Settings > Computer Use.")
        case .accessibilityPermissionRequired:
            pluginLocalization.string("Accessibility permission is required. Open Lumi Settings > Computer Use.")
        case .noMatchingWindow:
            pluginLocalization.string("No matching on-screen application window was found.")
        case .applicationNotAllowed(let name):
            pluginLocalization.string("Control of {app} is not allowed. Add it under Lumi Settings > Computer Use.")
                .replacingOccurrences(of: "{app}", with: name)
        case .observationNotFound:
            pluginLocalization.string("The observation does not exist. Call computer_observe again.")
        case .staleObservation:
            pluginLocalization.string("The target window changed since the screenshot was captured. Call computer_observe again.")
        case .invalidArguments(let message):
            pluginLocalization.string("Invalid Computer Use arguments: {message}")
                .replacingOccurrences(of: "{message}", with: message)
        case .captureFailed:
            pluginLocalization.string("The target window could not be captured.")
        case .eventCreationFailed:
            pluginLocalization.string("A macOS input event could not be created.")
        case .secureInputBlocked:
            pluginLocalization.string("Typing into a secure text field is blocked.")
        case .visionModelRequired:
            pluginLocalization.string("Computer Use requires a model that supports both vision and tools. Select a compatible model and try again.")
        }
    }
}
