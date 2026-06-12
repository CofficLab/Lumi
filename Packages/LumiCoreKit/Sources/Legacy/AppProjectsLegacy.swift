import Foundation
import SwiftUI

/// Legacy project model used by editor extension packages (e.g. Xcode preload).
public struct Project: Identifiable, Equatable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

private struct StoredProject: Codable {
    let name: String
    let path: String
}

@MainActor
public final class AppProjectsVM: ObservableObject {
    public static let shared = AppProjectsVM()

    nonisolated(unsafe) public static var recentProjectsProvider: @Sendable () -> [Project] = { [] }

    public func getRecentProjects() -> [Project] {
        let projects = Self.recentProjectsProvider()
        if !projects.isEmpty { return projects }
        return Self.loadRecentProjectsFromDisk()
    }

    @MainActor
    private static func loadRecentProjectsFromDisk() -> [Project] {
        let settingsDirectory = LumiCore.pluginDataDirectory(for: "Projects")
            .appendingPathComponent("settings", isDirectory: true)
        let fileURL = settingsDirectory.appendingPathComponent("projects.json", isDirectory: false)
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([StoredProject].self, from: data)
        else {
            return []
        }
        return stored.map { Project(name: $0.name, path: $0.path) }
    }
}
