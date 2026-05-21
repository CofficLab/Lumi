import AppKit
import Foundation

/// 抽象 `NSWorkspace`，便于单元测试
public protocol WorkspaceOpening: Sendable {
    func open(_ url: URL)
    func activateFileViewerSelecting(_ urls: [URL])
    func urlForApplication(bundleIdentifier: String) -> URL?
    func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        activates: Bool
    )
}

public enum WorkspaceEnvironment {
    nonisolated(unsafe) public static var workspace: any WorkspaceOpening = SystemWorkspaceOpener.shared
}

public final class SystemWorkspaceOpener: WorkspaceOpening, @unchecked Sendable {
    public static let shared = SystemWorkspaceOpener()

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    public func activateFileViewerSelecting(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    public func urlForApplication(bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    public func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        activates: Bool
    ) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration)
    }
}
