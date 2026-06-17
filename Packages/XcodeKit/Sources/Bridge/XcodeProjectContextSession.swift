import Foundation

/// Per-editor project context session. Prefer injecting this over the global bridge singleton.
@MainActor
public final class XcodeProjectContextSession {
    public let bridge: XcodeProjectContextBridge

    public init(bridge: XcodeProjectContextBridge = .shared) {
        self.bridge = bridge
    }

    public var activeProjectPath: String? { bridge.activeProjectPath }
    public var isXcodeProject: Bool { bridge.isXcodeProject }
    public var cachedState: BridgeCachedState? { bridge.cachedState }

    public func projectOpened(at path: String) async {
        await bridge.projectOpened(at: path)
    }

    public func projectClosed() {
        bridge.projectClosed()
    }

    public func resyncBuildContext() async {
        await bridge.resyncBuildContext()
    }
}

extension XcodeProjectContextBridge {
    /// Deprecated global singleton. Inject `XcodeProjectContextSession` for multi-window isolation.
    @available(*, deprecated, message: "Prefer XcodeProjectContextSession per editor window")
    public static var deprecatedShared: XcodeProjectContextBridge { shared }
}
