import Foundation

/// 检测文本中是否含有非拉丁（CJK）字符，用于强制 issue 以英文提交。
///
/// 判据选择：**只看 CJK 字形**，不做通用语种识别。
///
/// - 通用语种识别（`NLLanguageRecognizer`）对短文本（"crash on launch"）、
///   混排文本（日志 + 说明）判别不稳，且纯代码片段会被识别成其它语种，
///   误判方向不可控。
/// - CJK 字形是明确的「这段内容不是英文」信号。英文 issue 里出现中文/日文/韩文
///   字形本身就是需要改写的内容（哪怕只是引用了一段中文日志）。
///   因此按字形判定既不会漏判，也不会对正常英文产生误报。
enum EnglishLanguageGuard {
    /// 判定为「非英文」所需的最小非拉丁字符数。
    ///
    /// 取 3 而非 1：单个 CJK 字符可能来自误输入的标点或表情，
    /// 3 个以上才足以说明内容确实是非英文文本。
    static let minimumNonLatinCount = 3

    /// 非拉丁字符在整段文本中的最低占比，超过即判为非英文。
    ///
    /// 只靠字符计数会被「把中文拆到 title 与 body」绕过：两个字段各 2 个字符
    /// 都不到绝对阈值，但整份提交 100% 是非英文。占比判据对短文本同样有效，
    /// 同时仍容忍英文正文里偶发的 1~2 个 CJK 字符（占比很低）。
    static let minimumNonLatinRatio = 0.2

    /// 覆盖 CJK 表意文字、假名、谚文及 CJK 标点。
    private static let nonLatinRanges: [ClosedRange<UInt32>] = [
        0x3000...0x303F,   // CJK Symbols and Punctuation（、。《》等）
        0x3040...0x30FF,   // Hiragana + Katakana
        0x3400...0x4DBF,   // CJK Unified Ideographs Extension A
        0x4E00...0x9FFF,   // CJK Unified Ideographs
        0xAC00...0xD7AF,   // Hangul Syllables
        0xF900...0xFAFF,   // CJK Compatibility Ideographs
    ]

    /// 统计文本中的非拉丁字符数量。
    static func nonLatinCharacterCount(in text: String) -> Int {
        var count = 0
        for scalar in text.unicodeScalars where nonLatinRanges.contains(where: { $0.contains(scalar.value) }) {
            count += 1
        }
        return count
    }

    /// 判断文本是否含有足够多的非拉丁字符（即不是英文）。
    static func containsNonEnglishContent(_ text: String) -> Bool {
        let nonLatinCount = nonLatinCharacterCount(in: text)
        guard nonLatinCount > 0 else { return false }
        if nonLatinCount >= minimumNonLatinCount { return true }

        let scalarCount = text.unicodeScalars.count
        guard scalarCount > 0 else { return false }
        return Double(nonLatinCount) / Double(scalarCount) >= minimumNonLatinRatio
    }
}
