import AppKit
import Foundation

public enum ChatInputEditorRules {
    public static let imagePathExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic",
    ]

    public static func swiftToUTF16Index(_ swiftIndex: Int, in string: String) -> Int {
        let clampedIndex = min(max(swiftIndex, 0), string.count)
        guard let index = string.index(string.startIndex, offsetBy: clampedIndex, limitedBy: string.endIndex) else {
            return (string as NSString).length
        }
        return string.utf16.distance(from: string.startIndex, to: index)
    }

    public static func utf16ToSwiftIndex(_ utf16Index: Int, in string: String) -> Int {
        let utf16Clamped = min(max(utf16Index, 0), string.utf16.count)
        let utf16Start = string.utf16.startIndex
        guard let utf16Target = string.utf16.index(utf16Start, offsetBy: utf16Clamped, limitedBy: string.utf16.endIndex) else {
            return string.count
        }

        let swiftTarget: String.Index
        if let exactIndex = String.Index(utf16Target, within: string) {
            swiftTarget = exactIndex
        } else {
            swiftTarget = string.indices.last { index in
                string.utf16.distance(from: string.startIndex, to: index) <= utf16Clamped
            } ?? string.startIndex
        }

        return string.distance(from: string.startIndex, to: swiftTarget)
    }

    public static func isReturnKey(keyCode: UInt16, charactersIgnoringModifiers: String?) -> Bool {
        keyCode == 36 || keyCode == 76 || charactersIgnoringModifiers == "\r"
    }

    public static func shouldHandleReturnKey(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        guard isReturnKey(keyCode: keyCode, charactersIgnoringModifiers: charactersIgnoringModifiers) else {
            return false
        }
        return modifierFlags.intersection([.shift, .option, .command, .control]).isEmpty
    }

    public static func isEnterCommand(_ commandSelector: Selector) -> Bool {
        commandSelector == #selector(NSResponder.insertNewline(_:))
            || commandSelector == #selector(NSResponder.insertLineBreak(_:))
            || commandSelector == #selector(NSResponder.insertParagraphSeparator(_:))
    }

    public static func isChatImageFileURL(_ url: URL) -> Bool {
        imagePathExtensions.contains(url.pathExtension.lowercased())
    }

    public static func fileURL(fromDroppedString string: String) -> URL? {
        fileURLs(fromDroppedString: string).first
    }

    public static func fileURLs(fromDroppedString string: String) -> [URL] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lineURLs = trimmed
            .split(whereSeparator: \.isNewline)
            .compactMap { fileURL(fromSingleDroppedString: String($0)) }
        if !lineURLs.isEmpty {
            return lineURLs
        }

        return fileURL(fromSingleDroppedString: trimmed).map { [$0] } ?? []
    }

    private static func fileURL(fromSingleDroppedString string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }
        guard trimmed.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: trimmed)
    }
}
