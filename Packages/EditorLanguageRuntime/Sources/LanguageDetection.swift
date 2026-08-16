import Foundation

public enum LanguageDetection {
    public static func detect(
        descriptors: [EditorLanguageDescriptor],
        url: URL,
        prefixBuffer: String? = nil,
        suffixBuffer: String? = nil
    ) -> EditorLanguageContext {
        if let match = detectUsingURL(descriptors: descriptors, url: url) {
            return EditorLanguageContext(descriptor: match)
        }
        if let prefixBuffer,
           let match = detectUsingShebang(descriptors: descriptors, contents: prefixBuffer.lowercased()) {
            return EditorLanguageContext(descriptor: match)
        }
        if let prefixBuffer,
           let match = detectUsingModeline(
               descriptors: descriptors,
               prefixBuffer: prefixBuffer.lowercased(),
               suffixBuffer: suffixBuffer?.lowercased()
           ) {
            return EditorLanguageContext(descriptor: match)
        }
        return .plainText
    }

    private static func detectUsingURL(descriptors: [EditorLanguageDescriptor], url: URL) -> EditorLanguageDescriptor? {
        let fileName = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        for descriptor in descriptors {
            let extensions = descriptor.fileExtensions.map { $0.lowercased() }
            if extensions.contains(fileName) || extensions.contains(ext) {
                return descriptor
            }
        }
        return nil
    }

    private static func detectUsingShebang(
        descriptors: [EditorLanguageDescriptor],
        contents: String
    ) -> EditorLanguageDescriptor? {
        guard contents.hasPrefix("#!") else { return nil }
        let line = contents.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? contents
        // Token-based matching: raw substring checks produce false positives,
        // e.g. extension "h" matching "#!/bin/bash" or alias "sh" matching "#!/usr/bin/zsh".
        let tokens = line.split { !($0.isLetter || $0.isNumber) }.map(String.init)
        func matches(_ identifier: String) -> Bool {
            let id = identifier.lowercased()
            return tokens.contains {
                $0 == id || ($0.hasPrefix(id) && $0.dropFirst(id.count).allSatisfy(\.isNumber))
            }
        }
        for descriptor in descriptors {
            for alias in descriptor.shebangAliases where matches(alias) {
                return descriptor
            }
            if matches(descriptor.highlightLanguageId) { return descriptor }
            for ext in descriptor.fileExtensions where matches(ext) {
                return descriptor
            }
        }
        return nil
    }

    private static func detectUsingModeline(
        descriptors: [EditorLanguageDescriptor],
        prefixBuffer: String,
        suffixBuffer: String?
    ) -> EditorLanguageDescriptor? {
        let buffers = [prefixBuffer, suffixBuffer].compactMap { $0 }
        for buffer in buffers {
            if let ft = extractModelineValue(from: buffer, key: "ft") ?? extractModelineValue(from: buffer, key: "filetype"),
               let match = descriptors.first(where: {
                   $0.highlightLanguageId == ft
                       || $0.languageId == ft
                       || $0.additionalModelineIds.contains(ft)
                       || $0.fileExtensions.contains(ft)
               }) {
                return match
            }
            if let mode = extractModelineValue(from: buffer, key: "mode"),
               let match = descriptors.first(where: {
                   $0.highlightLanguageId == mode
                       || $0.languageId == mode
                       || $0.additionalModelineIds.contains(mode)
               }) {
                return match
            }
        }
        return nil
    }

    private static func extractModelineValue(from buffer: String, key: String) -> String? {
        // \b prevents matching the key inside words (e.g. `soft=` must not parse as `ft=`).
        let patterns = [
            "\\bvim:.*\\b\(key)[=:]\\s*([a-zA-Z0-9_+-]+)",
            "-\\*-\\s*\\b\(key)[=:]\\s*([a-zA-Z0-9_+-]+)",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(buffer.startIndex..<buffer.endIndex, in: buffer)
            guard let match = regex.firstMatch(in: buffer, range: range),
                  let valueRange = Range(match.range(at: 1), in: buffer) else { continue }
            return String(buffer[valueRange])
        }
        return nil
    }
}
