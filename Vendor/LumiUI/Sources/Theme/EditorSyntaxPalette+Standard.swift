import SwiftUI

extension EditorSyntaxPalette {
    /// Xcode Dark / 通用深色 fallback（与 `EditorThemeAdapter.fallbackTheme` 对齐）。
    public static func standard(isDark: Bool) -> EditorSyntaxPalette {
        isDark ? preset(.xcodeDark) : preset(.xcodeLight)
    }

    public static func preset(_ preset: EditorSyntaxPalettePreset) -> EditorSyntaxPalette {
        switch preset {
        case .lumiDark:
            fallthrough
        case .xcodeDark:
            return EditorSyntaxPalette(
                text: .color("FFFFFF"),
                insertionPointHex: "FFFFFF",
                invisibles: .color("666666"),
                backgroundHex: "1D1D23",
                lineHighlightHex: "34373F",
                selectionHex: "4C5972",
                selectionAlpha: 0.6,
                keywords: .color("FF265F"),
                commands: .color("C8B68A"),
                types: .color("42CCD5"),
                attributes: .color("D598EA"),
                variables: .color("FFFFFF"),
                values: .color("C8B68A"),
                numbers: .color("FF6348"),
                strings: .color("FF6A56"),
                characters: .color("FF6A56"),
                comments: .color("757F8B")
            )
        case .lumiLight:
            fallthrough
        case .xcodeLight:
            return EditorSyntaxPalette(
                text: .color("1C1C1F"),
                insertionPointHex: "1C1C1F",
                invisibles: .color("B3B3B8"),
                backgroundHex: "FAFAFC",
                lineHighlightHex: "F0F2F8",
                selectionHex: "B8D1FA",
                selectionAlpha: 0.55,
                keywords: .color("C71485"),
                commands: .color("8C6300"),
                types: .color("216EB8"),
                attributes: .color("8C45AD"),
                variables: .color("1C1C1F"),
                values: .color("8C6300"),
                numbers: .color("1C73D9"),
                strings: .color("C51A17"),
                characters: .color("C51A17"),
                comments: .color("6B7885")
            )
        case .dracula:
            return EditorSyntaxPalette(
                text: .color("F8F8F2"),
                insertionPointHex: "F8F8F2",
                invisibles: .color("6272A4"),
                backgroundHex: "282A36",
                lineHighlightHex: "313341",
                selectionHex: "44475A",
                selectionAlpha: 0.65,
                keywords: .color("FF79C6"),
                commands: .color("FFB86C"),
                types: .color("8BE9FD"),
                attributes: .color("BD93F9"),
                variables: .color("F8F8F2"),
                values: .color("FFB86C"),
                numbers: .color("BD93F9"),
                strings: .color("F1FA8C"),
                characters: .color("F1FA8C"),
                comments: .color("6272A4")
            )
        case .oneDark:
            return EditorSyntaxPalette(
                text: .color("ABB2BF"),
                insertionPointHex: "ABB2BF",
                invisibles: .color("5C6370"),
                backgroundHex: "282C34",
                lineHighlightHex: "2C313A",
                selectionHex: "3E4451",
                selectionAlpha: 0.6,
                keywords: .color("C678DD"),
                commands: .color("D19A66"),
                types: .color("E5C07B"),
                attributes: .color("D19A66"),
                variables: .color("E06C75"),
                values: .color("D19A66"),
                numbers: .color("D19A66"),
                strings: .color("98C379"),
                characters: .color("98C379"),
                comments: .color("5C6370")
            )
        case .vscodeDark:
            return EditorSyntaxPalette(
                text: .color("D4D4D4"),
                insertionPointHex: "AEAFAD",
                invisibles: .color("6A6A6A"),
                backgroundHex: "1E1E1E",
                lineHighlightHex: "2A2D2E",
                selectionHex: "264F78",
                selectionAlpha: 0.55,
                keywords: .color("569CD6"),
                commands: .color("DCDCAA"),
                types: .color("4EC9B0"),
                attributes: .color("9CDCFE"),
                variables: .color("9CDCFE"),
                values: .color("CE9178"),
                numbers: .color("B5CEA8"),
                strings: .color("CE9178"),
                characters: .color("CE9178"),
                comments: .color("6A9955")
            )
        case .vscodeLight:
            return EditorSyntaxPalette(
                text: .color("000000"),
                insertionPointHex: "000000",
                invisibles: .color("BFBFBF"),
                backgroundHex: "FFFFFF",
                lineHighlightHex: "F5F5F5",
                selectionHex: "ADD6FF",
                selectionAlpha: 0.55,
                keywords: .color("0000FF"),
                commands: .color("795E26"),
                types: .color("267F99"),
                attributes: .color("001080"),
                variables: .color("001080"),
                values: .color("A31515"),
                numbers: .color("098658"),
                strings: .color("A31515"),
                characters: .color("A31515"),
                comments: .color("008000")
            )
        case .github:
            return EditorSyntaxPalette(
                text: .color("24292F"),
                insertionPointHex: "24292F",
                invisibles: .color("8C959F"),
                backgroundHex: "FFFFFF",
                lineHighlightHex: "F6F8FA",
                selectionHex: "B6D3FC",
                selectionAlpha: 0.55,
                keywords: .color("CF222E"),
                commands: .color("953800"),
                types: .color("0550AE"),
                attributes: .color("8250DF"),
                variables: .color("24292F"),
                values: .color("953800"),
                numbers: .color("0550AE"),
                strings: .color("0A3069"),
                characters: .color("0A3069"),
                comments: .color("6E7781")
            )
        case .githubDark:
            return EditorSyntaxPalette(
                text: .color("C9D1D9"),
                insertionPointHex: "C9D1D9",
                invisibles: .color("484F58"),
                backgroundHex: "0D1117",
                lineHighlightHex: "161B22",
                selectionHex: "264F78",
                selectionAlpha: 0.55,
                keywords: .color("FF7B72"),
                commands: .color("D2A8FF"),
                types: .color("79C0FF"),
                attributes: .color("FFA657"),
                variables: .color("C9D1D9"),
                values: .color("FFA657"),
                numbers: .color("79C0FF"),
                strings: .color("A5D6FF"),
                characters: .color("A5D6FF"),
                comments: .color("8B949E")
            )
        case .skyDark:
            return EditorSyntaxPalette(
                text: .color("EAF6FF"),
                insertionPointHex: "EAF6FF",
                invisibles: .color("4B647A"),
                backgroundHex: "0D1B2E",
                lineHighlightHex: "162A44",
                selectionHex: "1E3A5F",
                selectionAlpha: 0.6,
                keywords: .color("60A5FA"),
                commands: .color("FACC15"),
                types: .color("38BDF8"),
                attributes: .color("93C5FD"),
                variables: .color("EAF6FF"),
                values: .color("FBBF24"),
                numbers: .color("38BDF8"),
                strings: .color("FDE68A"),
                characters: .color("FDE68A"),
                comments: .color("7F97AF")
            )
        case .skyLight:
            return EditorSyntaxPalette(
                text: .color("102033"),
                insertionPointHex: "102033",
                invisibles: .color("7890A3"),
                backgroundHex: "FFFFFF",
                lineHighlightHex: "EAF7FF",
                selectionHex: "BAE6FD",
                selectionAlpha: 0.55,
                keywords: .color("0284C7"),
                commands: .color("D97706"),
                types: .color("0EA5E9"),
                attributes: .color("0369A1"),
                variables: .color("102033"),
                values: .color("B45309"),
                numbers: .color("0284C7"),
                strings: .color("B91C1C"),
                characters: .color("B91C1C"),
                comments: .color("64748B")
            )
        }
    }
}
