import Foundation

enum MLXModelDownloader {
    private static let completionMarker = ".lumi-mlx-complete"

    static func isComplete(directory: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.appendingPathComponent(completionMarker).path),
              fileExistsNonEmpty(directory.appendingPathComponent("config.json")),
              fileExistsNonEmpty(directory.appendingPathComponent("tokenizer.json")) else {
            return false
        }

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        return enumerator.contains { item in
            guard let url = item as? URL, url.pathExtension.lowercased() == "safetensors",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else {
                return false
            }
            return values.isRegularFile == true && (values.fileSize ?? 0) > 0
        }
    }

    static func markComplete(directory: URL) throws {
        try Data("Lumi MLX model cache\n".utf8).write(
            to: directory.appendingPathComponent(completionMarker),
            options: .atomic
        )
    }

    private static func fileExistsNonEmpty(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]) else { return false }
        return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }
}
