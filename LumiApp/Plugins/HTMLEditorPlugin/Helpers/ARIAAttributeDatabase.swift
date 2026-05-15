import Foundation

/// ARIA 属性元数据数据库
///
/// 提供 WAI-ARIA 无障碍属性的补全和提示。
enum ARIAAttributeDatabase {
    // MARK: - ARIA 角色

    static let roles: [(name: String, summary: String)] = [
        ("alert", "A live region containing important information that should be announced to the user."),
        ("alertdialog", "A dialog element containing important information that requires user interaction."),
        ("article", "A section of content that could be used independently (blog post, news article, etc.)."),
        ("banner", "A region containing mostly site-oriented content rather than page-specific content."),
        ("button", "An interactive element that triggers an action when activated."),
        ("cell", "A cell in a tabular container."),
        ("checkbox", "A checkable input element with three states: checked, unchecked, or mixed."),
        ("columnheader", "A cell containing header information for a column in a grid."),
        ("combobox", "An element that controls a listbox and may allow text entry."),
        ("complementary", "A section of content that supports the main content but is meaningful on its own."),
        ("contentinfo", "A region containing information about the parent document (footers, copyright, etc.)."),
        ("dialog", "A window-like interface that separates content from the rest of the page."),
        ("directory", "A list of references to members of a group or directory."),
        ("document", "A region containing content that is perceivable but not interactive."),
        ("feed", "A scrollable list of content where items are dynamically loaded as the user scrolls."),
        ("figure", "A perceivable section containing content referenced from the main content."),
        ("form", "A landmark region containing a collection of form-associated elements."),
        ("grid", "A composite widget containing a collection of cells in a tabular format."),
        ("gridcell", "A cell in a grid that may contain focusable elements."),
        ("group", "A set of objects that are logically grouped together."),
        ("heading", "A heading for a section of the page."),
        ("img", "A container for images or other visual content."),
        ("link", "A reference to an internal or external resource."),
        ("list", "A group of non-interactive list items."),
        ("listbox", "A widget that allows the user to select one or more items from a list."),
        ("listitem", "A single item in a list."),
        ("log", "A live region containing a chronological sequence of messages."),
        ("main", "The main content of the document. There should be only one per page."),
        ("marquee", "A live region containing non-essential, scrolling text."),
        ("math", "Content that represents a mathematical expression."),
        ("menu", "A type of widget that offers a list of choices to the user."),
        ("menubar", "A presentation of a menu that is commonly rendered as a horizontal bar."),
        ("menuitem", "An item in a menu or menubar."),
        ("navigation", "A collection of links for navigating the document or related documents."),
        ("none", "An element whose implicit native role semantics is not mapped to the accessibility API."),
        ("note", "A section containing ancillary content, such as a footnote or annotation."),
        ("option", "A selectable item in a listbox or similar widget."),
        ("presentation", "Deprecated synonym for 'none'."),
        ("progressbar", "An element displaying the completion progress of a task."),
        ("radio", "A checkable input element in a group where only one can be checked."),
        ("radiogroup", "A group of radio buttons."),
        ("region", "A section of content perceivable as a landmark."),
        ("row", "A row of cells in a grid, table, or treegrid."),
        ("rowgroup", "A group of rows in a table or grid."),
        ("rowheader", "A cell containing header information for a row in a grid."),
        ("scrollbar", "A graphical object that controls the scrolling of content."),
        ("search", "A landmark region containing search-related functionality."),
        ("searchbox", "A type of textbox intended for search queries."),
        ("separator", "A divider between content that is visible to assistive technologies."),
        ("slider", "An input where the user selects a value from a range."),
        ("spinbutton", "An input for entering a numeric value that can be adjusted up or down."),
        ("status", "A live region containing advisory information that is not important enough for an alert."),
        ("switch", "A checkable input with two states: on and off."),
        ("tab", "A grouping label for content associated with a tablist."),
        ("table", "A tabular container with rows and columns of data."),
        ("tablist", "A list of tabs with associated panel content."),
        ("tabpanel", "The content area associated with a tab."),
        ("term", "A word or phrase with a corresponding definition."),
        ("textbox", "An input that allows free-form text entry."),
        ("timer", "A live region containing a timer or countdown."),
        ("toolbar", "A collection of commonly used functions represented as buttons."),
        ("tooltip", "A contextual popup that displays a description for an element."),
        ("tree", "A widget that allows the user to select from a collapsible hierarchical structure."),
        ("treegrid", "A grid with rows that can be expanded and collapsed."),
        ("treeitem", "An item in a tree widget."),
    ]

    static let roleMap: [String: String] = Dictionary(
        uniqueKeysWithValues: roles.map { ($0.name.lowercased(), $0.summary) }
    )

    // MARK: - ARIA 属性

    static let attributes: [(name: String, summary: String)] = [
        ("aria-activedescendant", "Identifies the currently active element when focus is on a composite widget."),
        ("aria-atomic", "Indicates whether assistive technologies should present all or only parts of a changed region."),
        ("aria-autocomplete", "Indicates whether inputting text could trigger display of predictions and how they are presented."),
        ("aria-busy", "Indicates an element is being modified and assistive technologies should defer updates."),
        ("aria-checked", "Indicates the current checked state of a checkbox, radio, or switch."),
        ("aria-colcount", "Defines the total number of columns in a table, grid, or treegrid."),
        ("aria-colindex", "Defines the column index of a cell in a table, grid, or treegrid."),
        ("aria-colspan", "Defines the number of columns spanned by a cell or gridcell."),
        ("aria-controls", "Identifies the element whose contents are controlled by the current element."),
        ("aria-current", "Indicates the element that represents the current item within a container or set."),
        ("aria-describedby", "Identifies the element that provides a detailed description of the current element."),
        ("aria-details", "Identifies the element that provides a detailed, extended description."),
        ("aria-disabled", "Indicates that the element is perceivable but not editable or operable."),
        ("aria-dropeffect", "Indicates what functions can be performed when a dragged object is released."),
        ("aria-errormessage", "Identifies the element that provides an error message."),
        ("aria-expanded", "Indicates whether a grouping element is expanded or collapsed."),
        ("aria-flowto", "Identifies the next element in the reading order."),
        ("aria-grabbed", "Indicates an element's 'grabbed' state in a drag-and-drop operation."),
        ("aria-haspopup", "Indicates the availability and type of interactive popup element."),
        ("aria-hidden", "Indicates whether the element is exposed to the accessibility API."),
        ("aria-invalid", "Indicates the entered value does not conform to the expected format."),
        ("aria-keyshortcuts", "Indicates keyboard shortcuts that activate an element."),
        ("aria-label", "Defines a string value that labels the current element."),
        ("aria-labelledby", "Identifies the element that labels the current element."),
        ("aria-level", "Defines the hierarchical level of an element."),
        ("aria-live", "Indicates an element will be updated and the type of updates to expect."),
        ("aria-modal", "Indicates whether an element is modal when displayed."),
        ("aria-multiline", "Indicates whether a textbox accepts multiple lines of input."),
        ("aria-multiselectable", "Indicates that the user may select more than one item from the current list."),
        ("aria-orientation", "Indicates whether a element's orientation is horizontal, vertical, or unknown."),
        ("aria-owns", "Identifies an element and its children owned by the current element."),
        ("aria-placeholder", "Defines a short hint of the expected value in a field."),
        ("aria-posinset", "Defines the position of an item in a set."),
        ("aria-pressed", "Indicates the current pressed state of a toggle button."),
        ("aria-readonly", "Indicates that the element is not editable but is otherwise operable."),
        ("aria-relevant", "Indicates what notifications the user agent will trigger when the accessibility tree is modified."),
        ("aria-required", "Indicates that user input is required on the element before a form may be submitted."),
        ("aria-roledescription", "Defines a human-readable description of the role of an element."),
        ("aria-rowcount", "Defines the total number of rows in a table, grid, or treegrid."),
        ("aria-rowindex", "Defines the row index of a cell in a table, grid, or treegrid."),
        ("aria-rowspan", "Defines the number of rows spanned by a cell or gridcell."),
        ("aria-selected", "Indicates the current selected state of a widget."),
        ("aria-setsize", "Defines the number of items in the current set of list items or treeitems."),
        ("aria-sort", "Indicates if items are sorted in ascending or descending order."),
        ("aria-valuemax", "Defines the maximum allowed value for a range widget."),
        ("aria-valuemin", "Defines the minimum allowed value for a range widget."),
        ("aria-valuenow", "Defines the current value for a range widget."),
        ("aria-valuetext", "Defines the human-readable text alternative of the current value."),
    ]

    static let attributeMap: [String: String] = Dictionary(
        uniqueKeysWithValues: attributes.map { ($0.name.lowercased(), $0.summary) }
    )

    // MARK: - 补全

    static func roleSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return roles
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { role in
                EditorCompletionSuggestion(
                    label: role.name,
                    insertText: role.name,
                    detail: role.summary.prefix(60) + (role.summary.count > 60 ? "..." : ""),
                    priority: 880
                )
            }
    }

    static func ariaSuggestions(prefix: String) -> [EditorCompletionSuggestion] {
        let normalized = prefix.lowercased()
        return attributes
            .filter { normalized.isEmpty || $0.name.hasPrefix(normalized) }
            .map { attr in
                EditorCompletionSuggestion(
                    label: attr.name,
                    insertText: attr.name,
                    detail: attr.summary.prefix(60) + (attr.summary.count > 60 ? "..." : ""),
                    priority: 880
                )
            }
    }

    /// 获取 ARIA 角色或属性的悬浮提示
    static func hoverMarkdown(for symbol: String) -> String? {
        let normalized = symbol.lowercased()

        if let summary = roleMap[normalized] {
            return """
            `role="\(symbol)"`

            \(summary)
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
