import AppKit
import Foundation
import SwiftUI
import XcodeKit

/// Per-window EditorSwift state (session + status bar view model).
@MainActor
public final class EditorSwiftWindowScope: ObservableObject {
    public let session: XcodeProjectContextSession
    public let statusBarViewModel: XcodeProjectStatusBarViewModel

    public init(session: XcodeProjectContextSession = XcodeProjectContextSession()) {
        self.session = session
        self.statusBarViewModel = XcodeProjectStatusBarViewModel(session: session)
    }
}

@MainActor
public enum EditorSwiftWindowScopeRegistry {
    private static var scopesByWindowNumber: [Int: EditorSwiftWindowScope] = [:]
    private static var fallbackScope: EditorSwiftWindowScope?

    public static var activeStatusBarViewModel: XcodeProjectStatusBarViewModel {
        activeScope()?.statusBarViewModel ?? XcodeProjectStatusBarViewModel.shared
    }

    public static var activeSession: XcodeProjectContextSession {
        activeScope()?.session ?? XcodeProjectContextSession()
    }

    public static func register(_ scope: EditorSwiftWindowScope, forWindowNumber windowNumber: Int) {
        scopesByWindowNumber[windowNumber] = scope
        fallbackScope = scope
    }

    public static func unregister(windowNumber: Int) {
        scopesByWindowNumber.removeValue(forKey: windowNumber)
        if scopesByWindowNumber.isEmpty {
            fallbackScope = nil
        }
    }

    private static func activeScope() -> EditorSwiftWindowScope? {
        if let keyWindow = NSApp.keyWindow ?? NSApp.mainWindow,
           let scope = scopesByWindowNumber[keyWindow.windowNumber] {
            return scope
        }
        return fallbackScope ?? scopesByWindowNumber.values.first
    }
}
