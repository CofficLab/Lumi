import Foundation

/// HTML 知识库
///
/// 提供标准 HTML 标签、属性和值的定义，用于补全和悬浮提示。
enum HTMLKnowledgeBase {
    // MARK: - 支持的语言

    static let supportedLanguageIDs: Set<String> = ["html", "htm"]

    static func isSupported(languageId: String) -> Bool {
        supportedLanguageIDs.contains(languageId.lowercased())
    }

    // MARK: - 自闭合标签

    static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    // MARK: - 标签定义

    struct TagDefinition: Sendable {
        let name: String
        let summary: String
        let attributes: [String]
        let isVoid: Bool
    }

    static let tags: [TagDefinition] = [
        .init(name: "div", summary: "Generic block-level container for grouping content.", attributes: ["class", "id", "style"], isVoid: false),
        .init(name: "span", summary: "Generic inline container for phrasing content.", attributes: ["class", "id", "style"], isVoid: false),
        .init(name: "p", summary: "Defines a paragraph of text.", attributes: ["class", "id", "style"], isVoid: false),
        .init(name: "a", summary: "Creates a hyperlink to other pages, files, or locations.", attributes: ["href", "target", "rel", "download", "class", "id"], isVoid: false),
        .init(name: "img", summary: "Embeds an image into the document.", attributes: ["src", "alt", "width", "height", "loading", "class", "id"], isVoid: true),
        .init(name: "ul", summary: "Defines an unordered (bulleted) list.", attributes: ["class", "id"], isVoid: false),
        .init(name: "ol", summary: "Defines an ordered (numbered) list.", attributes: ["class", "id", "start", "type"], isVoid: false),
        .init(name: "li", summary: "Defines a list item inside <ul> or <ol>.", attributes: ["class", "id", "value"], isVoid: false),
        .init(name: "h1", summary: "Top-level heading. Use one per page for the main title.", attributes: ["class", "id"], isVoid: false),
        .init(name: "h2", summary: "Second-level heading for major sections.", attributes: ["class", "id"], isVoid: false),
        .init(name: "h3", summary: "Third-level heading for sub-sections.", attributes: ["class", "id"], isVoid: false),
        .init(name: "h4", summary: "Fourth-level heading.", attributes: ["class", "id"], isVoid: false),
        .init(name: "h5", summary: "Fifth-level heading.", attributes: ["class", "id"], isVoid: false),
        .init(name: "h6", summary: "Sixth-level heading.", attributes: ["class", "id"], isVoid: false),
        .init(name: "form", summary: "Defines an interactive form for user input.", attributes: ["action", "method", "enctype", "class", "id"], isVoid: false),
        .init(name: "input", summary: "Creates an interactive form control.", attributes: ["type", "name", "value", "placeholder", "required", "disabled", "class", "id"], isVoid: true),
        .init(name: "button", summary: "Creates a clickable button.", attributes: ["type", "disabled", "class", "id"], isVoid: false),
        .init(name: "textarea", summary: "Creates a multi-line text input control.", attributes: ["name", "rows", "cols", "placeholder", "class", "id"], isVoid: false),
        .init(name: "select", summary: "Creates a dropdown selection control.", attributes: ["name", "multiple", "class", "id"], isVoid: false),
        .init(name: "option", summary: "Defines an option inside a <select> element.", attributes: ["value", "selected", "disabled"], isVoid: false),
        .init(name: "label", summary: "Associates a text label with a form control.", attributes: ["for", "class", "id"], isVoid: false),
        .init(name: "table", summary: "Defines a table for tabular data.", attributes: ["class", "id"], isVoid: false),
        .init(name: "thead", summary: "Groups header rows in a table.", attributes: ["class"], isVoid: false),
        .init(name: "tbody", summary: "Groups body rows in a table.", attributes: ["class"], isVoid: false),
        .init(name: "tr", summary: "Defines a row of cells in a table.", attributes: ["class"], isVoid: false),
        .init(name: "th", summary: "Defines a header cell in a table.", attributes: ["scope", "colspan", "rowspan", "class"], isVoid: false),
        .init(name: "td", summary: "Defines a data cell in a table.", attributes: ["colspan", "rowspan", "class"], isVoid: false),
        .init(name: "header", summary: "Defines introductory content or a group of navigational aids.", attributes: ["class", "id"], isVoid: false),
        .init(name: "footer", summary: "Defines the footer for its nearest sectioning content.", attributes: ["class", "id"], isVoid: false),
        .init(name: "nav", summary: "Defines a section of navigation links.", attributes: ["class", "id"], isVoid: false),
        .init(name: "main", summary: "Represents the dominant content of the document body.", attributes: ["class", "id"], isVoid: false),
        .init(name: "section", summary: "Defines a standalone section of content.", attributes: ["class", "id"], isVoid: false),
        .init(name: "article", summary: "Represents a self-contained composition in a page.", attributes: ["class", "id"], isVoid: false),
        .init(name: "aside", summary: "Represents content tangentially related to the main content.", attributes: ["class", "id"], isVoid: false),
        .init(name: "figure", summary: "Represents self-contained content with an optional caption.", attributes: ["class"], isVoid: false),
        .init(name: "figcaption", summary: "Provides a caption for a <figure> element.", attributes: ["class"], isVoid: false),
        .init(name: "details", summary: "Creates a disclosure widget with summary and details.", attributes: ["open", "class"], isVoid: false),
        .init(name: "summary", summary: "Provides the summary or legend for a <details> element.", attributes: ["class"], isVoid: false),
        .init(name: "dialog", summary: "Defines a dialog box or other interactive component.", attributes: ["open", "class"], isVoid: false),
        .init(name: "video", summary: "Embeds video content with playback controls.", attributes: ["src", "controls", "autoplay", "muted", "loop", "width", "height", "class"], isVoid: false),
        .init(name: "audio", summary: "Embeds audio content with playback controls.", attributes: ["src", "controls", "autoplay", "muted", "loop", "class"], isVoid: false),
        .init(name: "source", summary: "Specifies multiple media resources for <video> or <audio>.", attributes: ["src", "type", "media"], isVoid: true),
        .init(name: "canvas", summary: "Provides a resolution-dependent bitmap canvas for rendering graphics.", attributes: ["width", "height", "class", "id"], isVoid: false),
        .init(name: "svg", summary: "Container for SVG graphics.", attributes: ["width", "height", "viewBox", "xmlns", "class"], isVoid: false),
        .init(name: "iframe", summary: "Embeds another HTML page into the current page.", attributes: ["src", "width", "height", "title", "loading", "class"], isVoid: false),
        .init(name: "br", summary: "Produces a line break in text.", attributes: [], isVoid: true),
        .init(name: "hr", summary: "Represents a thematic break between paragraph-level elements.", attributes: ["class"], isVoid: true),
        .init(name: "strong", summary: "Indicates strong importance, seriousness, or urgency.", attributes: ["class"], isVoid: false),
        .init(name: "em", summary: "Marks text with stress emphasis.", attributes: ["class"], isVoid: false),
        .init(name: "code", summary: "Represents a fragment of computer code.", attributes: ["class"], isVoid: false),
        .init(name: "pre", summary: "Represents preformatted text.", attributes: ["class"], isVoid: false),
        .init(name: "blockquote", summary: "Represents a section quoted from another source.", attributes: ["cite", "class"], isVoid: false),
        .init(name: "meta", summary: "Provides metadata about the document.", attributes: ["name", "content", "charset", "http-equiv"], isVoid: true),
        .init(name: "link", summary: "Specifies relationships between the document and external resources.", attributes: ["rel", "href", "type", "as", "class"], isVoid: true),
        .init(name: "script", summary: "Embeds or references executable code.", attributes: ["src", "type", "async", "defer", "nomodule"], isVoid: false),
        .init(name: "style", summary: "Contains style information for the document.", attributes: ["type", "media"], isVoid: false),
        .init(name: "title", summary: "Sets the document title shown in the browser tab.", attributes: [], isVoid: false),
        .init(name: "head", summary: "Contains metadata and links for the document.", attributes: [], isVoid: false),
        .init(name: "body", summary: "Represents the content of the document.", attributes: ["class", "id"], isVoid: false),
        .init(name: "html", summary: "Root element of an HTML document.", attributes: ["lang"], isVoid: false),
    ]

    static let tagMap: [String: TagDefinition] = Dictionary(
        uniqueKeysWithValues: tags.map { ($0.name.lowercased(), $0) }
    )

    // MARK: - 全局属性

    static let globalAttributes: [(name: String, summary: String)] = [
        ("class", "Space-separated list of CSS class names."),
        ("id", "Unique identifier for the element."),
        ("style", "Inline CSS styles for the element."),
        ("title", "Advisory information for the element (tooltip)."),
        ("lang", "Language of the element's content."),
        ("tabindex", "Controls focus navigation order."),
        ("hidden", "Hides the element from rendering."),
        ("role", "Defines an ARIA role for accessibility."),
        ("aria-label", "Provides an accessible name for the element."),
        ("aria-hidden", "Controls whether the element is visible to accessibility tools."),
        ("data-*", "Custom data attributes for private page data."),
    ]

    static let attributeMap: [String: String] = Dictionary(
        uniqueKeysWithValues: globalAttributes.map { ($0.name, $0.summary) }
    )

    // MARK: - 补全

    static func tagSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return tags
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { tag in
                EditorCompletionSuggestion(
                    label: tag.name,
                    insertText: tag.name,
                    detail: tag.summary,
                    priority: 930
                )
            }
    }

    static func attributeSuggestions(prefix: String, for tagName: String? = nil) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()

        // 标签专属属性
        var suggestions: [EditorCompletionSuggestion] = []
        if let tagName, let tag = tagMap[tagName] {
            suggestions = tag.attributes
                .filter { normalized.isEmpty || $0.hasPrefix(normalized) }
                .map { attr in
                    EditorCompletionSuggestion(
                        label: attr,
                        insertText: attr,
                        detail: "\(tagName) attribute",
                        priority: 940
                    )
                }
        }

        // 全局属性
        let globalMatches = globalAttributes
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { attr in
                EditorCompletionSuggestion(
                    label: attr.name,
                    insertText: attr.name,
                    detail: attr.summary,
                    priority: 920
                )
            }

        return suggestions + globalMatches
    }

    // MARK: - 悬浮提示

    static func hoverMarkdown(for symbol: String) -> String? {
        let normalized = symbol.lowercased()

        if let tag = tagMap[normalized] {
            let attrs = tag.attributes.isEmpty ? "" : "\n\nCommon attributes: `\(tag.attributes.joined(separator: "`, `"))`"
            let selfClosing = tag.isVoid ? "\n\n⚠️ Self-closing (void) element." : ""
            return """
            `<\(tag.name)>`

            \(tag.summary)\(attrs)\(selfClosing)
            """
        }

        if let summary = attributeMap[normalized] {
            return """
            `\(symbol)`

            \(summary)
            """
        }

        return nil
    }
}
