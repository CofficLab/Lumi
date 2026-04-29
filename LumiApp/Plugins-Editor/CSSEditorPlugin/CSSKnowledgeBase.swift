import Foundation

struct CSSPropertyDefinition: Sendable {
    let name: String
    let syntax: String
    let summary: String
    let values: [String]
}

enum CSSKnowledgeBase {
    static let supportedLanguageIDs: Set<String> = ["css", "scss", "sass", "less"]

    static let globalValues: [String] = [
        "inherit", "initial", "unset", "revert", "revert-layer"
    ]

    static let valueDocs: [String: String] = [
        "block": "Generates a block box and starts on a new line.",
        "inline": "Flows inside text without forcing a line break.",
        "inline-block": "Flows inline while keeping a block formatting context.",
        "flex": "Creates a flex formatting context for one-dimensional layouts.",
        "grid": "Creates a grid formatting context for two-dimensional layouts.",
        "none": "Disables the feature or removes generated boxes depending on property context.",
        "relative": "Offsets the element relative to its normal position.",
        "absolute": "Positions the element against the nearest positioned ancestor.",
        "fixed": "Positions the element against the viewport.",
        "sticky": "Behaves relatively until a scroll threshold is crossed.",
        "solid": "Draws a single solid line.",
        "dashed": "Draws a dashed line.",
        "center": "Aligns content to the center.",
        "space-between": "Distributes items with equal gaps and no outer spacing.",
        "space-around": "Distributes items with equal surrounding space.",
        "space-evenly": "Distributes items with equal gaps including the edges.",
        "repeat": "Repeats the background image in both axes.",
        "no-repeat": "Prevents the background image from tiling."
    ]

    static let properties: [CSSPropertyDefinition] = [
        .init(name: "display", syntax: "display: <display-outside> || <display-inside>;", summary: "Controls the outer and inner display behavior of the element.", values: ["block", "inline", "inline-block", "flex", "grid", "none"]),
        .init(name: "position", syntax: "position: static | relative | absolute | fixed | sticky;", summary: "Defines how the element is positioned in normal flow or against a containing block.", values: ["static", "relative", "absolute", "fixed", "sticky"]),
        .init(name: "color", syntax: "color: <color>;", summary: "Sets the foreground text color.", values: ["currentColor", "transparent", "inherit"]),
        .init(name: "background", syntax: "background: <bg-layer># [, <final-bg-layer>]?", summary: "Shorthand for background color, image, position, size, repeat, origin, clip, and attachment.", values: ["transparent", "none", "repeat", "no-repeat", "center"]),
        .init(name: "background-color", syntax: "background-color: <color>;", summary: "Sets the background color behind the element content and padding.", values: ["transparent", "currentColor", "inherit"]),
        .init(name: "width", syntax: "width: auto | <length-percentage> | min-content | max-content | fit-content;", summary: "Sets the preferred inline size of the box.", values: ["auto", "min-content", "max-content", "fit-content", "100%"]),
        .init(name: "height", syntax: "height: auto | <length-percentage> | min-content | max-content | fit-content;", summary: "Sets the preferred block size of the box.", values: ["auto", "min-content", "max-content", "fit-content", "100%"]),
        .init(name: "margin", syntax: "margin: <length-percentage>{1,4} | auto;", summary: "Shorthand for the outer margins on all four sides.", values: ["0", "auto", "1rem", "2rem"]),
        .init(name: "padding", syntax: "padding: <length-percentage>{1,4};", summary: "Shorthand for the inner padding on all four sides.", values: ["0", "0.5rem", "1rem", "2rem"]),
        .init(name: "border", syntax: "border: <line-width> || <line-style> || <color>;", summary: "Shorthand for border width, style, and color.", values: ["1px solid", "none", "solid", "dashed", "transparent"]),
        .init(name: "border-radius", syntax: "border-radius: <length-percentage>{1,4} [ / <length-percentage>{1,4} ]?;", summary: "Rounds the corners of the border box.", values: ["0", "4px", "8px", "9999px", "50%"]),
        .init(name: "font-size", syntax: "font-size: <absolute-size> | <relative-size> | <length-percentage>;", summary: "Sets the size of glyphs in the font.", values: ["12px", "14px", "16px", "1rem", "clamp(1rem, 2vw, 1.5rem)"]),
        .init(name: "font-weight", syntax: "font-weight: normal | bold | bolder | lighter | <number>;", summary: "Controls the thickness of glyph strokes.", values: ["normal", "bold", "400", "500", "700"]),
        .init(name: "line-height", syntax: "line-height: normal | <number> | <length-percentage>;", summary: "Sets the height of line boxes in inline formatting.", values: ["normal", "1.2", "1.5", "2"]),
        .init(name: "text-align", syntax: "text-align: start | end | left | right | center | justify;", summary: "Sets horizontal alignment for inline content inside a block container.", values: ["left", "right", "center", "justify", "start"]),
        .init(name: "justify-content", syntax: "justify-content: start | end | center | space-between | space-around | space-evenly;", summary: "Distributes items along the main axis in flex and grid containers.", values: ["start", "end", "center", "space-between", "space-around", "space-evenly"]),
        .init(name: "align-items", syntax: "align-items: stretch | start | end | center | baseline;", summary: "Sets the default cross-axis alignment for flex or grid items.", values: ["stretch", "start", "end", "center", "baseline"]),
        .init(name: "gap", syntax: "gap: <length-percentage>{1,2};", summary: "Sets gutters between rows and columns in flex, grid, and multi-column layouts.", values: ["0", "0.5rem", "1rem", "2rem"]),
        .init(name: "grid-template-columns", syntax: "grid-template-columns: none | <track-list> | <auto-track-list>;", summary: "Defines the column tracks of a grid container.", values: ["1fr", "repeat(2, 1fr)", "repeat(auto-fit, minmax(12rem, 1fr))"]),
        .init(name: "box-shadow", syntax: "box-shadow: none | <shadow>#;", summary: "Applies one or more drop shadows to the element box.", values: ["none", "0 1px 2px rgb(0 0 0 / 0.08)", "0 12px 32px rgb(0 0 0 / 0.16)"]),
        .init(name: "opacity", syntax: "opacity: <alpha-value>;", summary: "Sets the transparency of the entire element.", values: ["0", "0.5", "1"]),
        .init(name: "transition", syntax: "transition: <single-transition>#;", summary: "Shorthand for transition-property, duration, timing function, and delay.", values: ["none", "all 150ms ease", "opacity 200ms ease-in-out"])
    ]

    static let propertyMap: [String: CSSPropertyDefinition] = Dictionary(
        uniqueKeysWithValues: properties.map { ($0.name.lowercased(), $0) }
    )

    static func isSupported(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId.lowercased())
    }

    static func propertySuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return properties
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map {
                EditorCompletionSuggestion(
                    label: $0.name,
                    insertText: $0.name,
                    detail: $0.syntax,
                    priority: 920
                )
            }
    }

    static func valueSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let candidates = Set(globalValues)
            .union(properties.flatMap(\.values))
            .sorted()

        return candidates
            .filter { normalized.isEmpty || $0.lowercased().hasPrefix(normalized) }
            .map {
                EditorCompletionSuggestion(
                    label: $0,
                    insertText: $0,
                    detail: valueDocs[$0] ?? "Common CSS value",
                    priority: 860
                )
            }
    }

    static func hoverMarkdown(for symbol: String) -> String? {
        let normalized = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let property = propertyMap[normalized] {
            let values = property.values.isEmpty ? "" : "\n\nTypical values: `\(property.values.joined(separator: "`, `"))`"
            return """
            `\(property.name)`

            \(property.summary)

            Syntax: `\(property.syntax)`\(values)
            """
        }
        if let valueDoc = valueDocs[normalized] {
            return """
            `\(symbol)`

            \(valueDoc)
            """
        }
        return nil
    }
}
