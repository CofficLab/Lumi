import Foundation

public enum LanguageResourceLocator {
    public static func resourceURL(
        in bundle: Bundle,
        grammarFolderName: String,
        fileName: String
    ) -> URL? {
        let relativePath = "\(grammarFolderName)/\(fileName)"
        let candidates = [
            bundle.resourceURL?.appendingPathComponent(relativePath),
            bundle.resourceURL?.appendingPathComponent("Resources/\(relativePath)"),
        ]
        return candidates.first { url in
            guard let url else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        } ?? candidates.compactMap { $0 }.first
    }

    public static func highlightURLs(
        in bundle: Bundle,
        grammarFolderName: String,
        additionalStems: Set<String> = []
    ) -> [URL] {
        var urls: [URL] = []
        if let highlights = resourceURL(in: bundle, grammarFolderName: grammarFolderName, fileName: "highlights.scm") {
            urls.append(highlights)
        }
        for stem in additionalStems.sorted() {
            if let url = resourceURL(in: bundle, grammarFolderName: grammarFolderName, fileName: "\(stem).scm") {
                urls.append(url)
            }
        }
        return urls
    }
}
