import Foundation
import SwiftUI

@MainActor
final class AppIconDesignerViewModel: ObservableObject {
    @Published var exportDirectory: String = ""
    @Published var isExporting = false

    let store: AppIconArtifactStore
    private let exportService: AppIconExportService

    init(
        store: AppIconArtifactStore = .shared,
        exportService: AppIconExportService = AppIconExportService()
    ) {
        self.store = store
        self.exportService = exportService
        self.exportDirectory = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
            .first?
            .path ?? FileManager.default.currentDirectoryPath
    }

    var selectedArtifact: AppIconArtifact? {
        store.selectedArtifact
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
                outputDirectory: URL(fileURLWithPath: exportDirectory, isDirectory: true)
            )
            store.setExportURL(result.appIconSetURL)
        } catch {
            store.setError(error.localizedDescription)
        }
    }
}
