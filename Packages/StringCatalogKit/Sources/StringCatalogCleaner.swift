import Foundation

public struct StringCatalogCleanResult: Equatable, Sendable {
    public let source: String
    public let removedCount: Int
}

public enum StringCatalogCleaner {
    public static func removingStaleEntries(from source: String) throws -> StringCatalogCleanResult {
        let data = Data(source.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        guard var root = object as? [String: Any],
              var strings = root["strings"] as? [String: Any] else {
            return StringCatalogCleanResult(source: source, removedCount: 0)
        }

        let staleKeys = strings.compactMap { key, value -> String? in
            guard let entry = value as? [String: Any],
                  entry["extractionState"] as? String == "stale" else {
                return nil
            }
            return key
        }

        guard !staleKeys.isEmpty else {
            return StringCatalogCleanResult(source: source, removedCount: 0)
        }

        for key in staleKeys {
            strings.removeValue(forKey: key)
        }
        root["strings"] = strings

        let outputData = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        var output = String(decoding: outputData, as: UTF8.self)
        if !output.hasSuffix("\n") {
            output.append("\n")
        }

        return StringCatalogCleanResult(source: output, removedCount: staleKeys.count)
    }
}
