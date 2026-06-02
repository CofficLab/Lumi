import Foundation
import SwiftUI

@MainActor
final class AppIconDesignerViewModel: ObservableObject {
    @Published var exportDirectory: String = ""
    @Published var isExporting = false

    let store: AppIconArtifactStore
    private let exportService: AppIconExportService
    private let fileManager: FileManager

    init(
        store: AppIconArtifactStore = .shared,
        exportService: AppIconExportService = AppIconExportService(),
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.exportService = exportService
        self.fileManager = fileManager
        self.exportDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
            .first?
            .path ?? FileManager.default.currentDirectoryPath
    }

    var selectedArtifact: AppIconArtifact? {
        store.selectedArtifact
    }

    func outputDirectoryURL() throws -> URL {
        let trimmed = exportDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppIconExportDirectoryError.empty
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            throw AppIconExportDirectoryError.notDirectory(url.path)
        }

        return url
    }

    func exportSelected() async {
        guard let selectedArtifact else {
            store.setError("No app icon candidate is selected.")
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let result = try exportService.exportAppIconSet(
                sourceImagePath: selectedArtifact.sourcePath,
                outputDirectory: outputDirectoryURL()
            )
            store.setExportURL(result.appIconSetURL)
        } catch {
            store.setError(error.localizedDescription)
        }
    }
}

enum AppIconExportDirectoryError: LocalizedError, Equatable {
    case empty
    case notDirectory(String)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Output directory cannot be empty."
        case .notDirectory(let path):
            return "Output path is not a directory: \(path)"
        }
    }
}
