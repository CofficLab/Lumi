import Foundation
import Combine

@MainActor
final class MLXModelManager: ObservableObject {
    @Published private(set) var cachedModelIDs: Set<String> = []
    @Published private(set) var totalCacheSize: Int64 = 0

    let systemRAMGB: Int

    init() {
        systemRAMGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        try? FileManager.default.createDirectory(at: MLXModelPaths.modelsDirectory, withIntermediateDirectories: true)
        refresh()
    }

    var series: [String] { MLXProviderCatalog.availableSeries }

    func models(for series: String) -> [MLXModelRegistration] {
        MLXProviderCatalog.models(forSeries: series)
    }

    func isCached(_ modelID: String) -> Bool {
        cachedModelIDs.contains(modelID)
    }

    func refresh() {
        cachedModelIDs = Set(MLXProviderCatalog.availableRegistrations.compactMap { model in
            MLXModelDownloader.isComplete(directory: MLXModelPaths.modelDirectory(for: model.id)) ? model.id : nil
        })
        totalCacheSize = directorySize(at: MLXModelPaths.modelsDirectory)
    }

    func deleteModel(_ modelID: String) throws {
        let directory = MLXModelPaths.modelDirectory(for: modelID)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
        refresh()
    }

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: totalCacheSize, countStyle: .file)
    }

    private func directorySize(at directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        return enumerator.reduce(into: Int64(0)) { total, item in
            guard let url = item as? URL,
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                  values.isDirectory != true else { return }
            total += Int64(values.fileSize ?? 0)
        }
    }
}
