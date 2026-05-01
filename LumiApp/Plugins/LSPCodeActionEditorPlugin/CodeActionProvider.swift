import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol
import AppKit

/// Code Action 提供者
/// 为诊断问题提供快速修复建议（灯泡图标）
@MainActor
final class CodeActionProvider: ObservableObject, SuperEditorCodeActionProvider {

    private let lspService: LSPService
    private let requestLifecycle = LSPRequestLifecycle()
    weak var editorExtensionRegistry: EditorExtensionRegistry?

    init(lspService: LSPService = .shared) {
        self.lspService = lspService
    }

    /// 当前可用的代码动作
    @Published var actions: [CodeActionItem] = []
    /// 是否在请求中
    @Published var isLoading: Bool = false
    /// 是否需要显示
    @Published var isVisible: Bool = false

    /// 请求代码动作
    func requestCodeActions(uri: String, range: LSPRange, diagnostics: [Diagnostic]) async {
        guard !diagnostics.isEmpty else {
            clear()
            return
        }

        isLoading = true
        requestLifecycle.run(
            operation: { [lspService] in
                await lspService.requestCodeAction(uri: uri, range: range, diagnostics: diagnostics)
            },
            apply: { [weak self] codeActions in
                guard let self else { return }
                isLoading = false
                actions = sortCodeActionItems(codeActions.compactMap(Self.codeActionItem(from:)))
                isVisible = !actions.isEmpty
            }
        )
    }

    /// 请求针对某一行诊断的代码动作
    func requestCodeActionsForLine(
        uri: String,
        line: Int,
        character: Int,
        diagnostics: [Diagnostic],
        languageId: String,
        selectedText: String?
    ) async {
        let lineDiagnostics = diagnostics.filter { diag in
            Int(diag.range.start.line) <= line && Int(diag.range.end.line) >= line
        }

        isLoading = true
        requestLifecycle.run(
            operation: { [lspService, weak editorExtensionRegistry] in
                let pluginContext = EditorCodeActionContext(
                    languageId: languageId,
                    line: line,
                    character: character,
                    selectedText: selectedText
                )
                async let pluginSuggestions = editorExtensionRegistry?.codeActionSuggestions(for: pluginContext) ?? []
                async let lspCodeActions: [CodeAction] = {
                    guard !lineDiagnostics.isEmpty, let firstDiag = lineDiagnostics.first else {
                        return []
                    }
                    return await lspService.requestCodeAction(
                        uri: uri,
                        range: firstDiag.range,
                        diagnostics: lineDiagnostics
                    )
                }()
                return await (pluginSuggestions, lspCodeActions)
            },
            apply: { [weak self] pluginSuggestions, codeActions in
                guard let self else { return }
                isLoading = false
                let pluginItems = pluginSuggestions.map { suggestion in
                    CodeActionItem(
                        title: suggestion.title,
                        kind: "plugin",
                        payload: .plugin(suggestion),
                        isPreferred: false
                    )
                }
                let lspItems = codeActions.compactMap(Self.codeActionItem(from:))
                let merged = sortCodeActionItems(lspItems + pluginItems)
                actions = merged
                isVisible = !merged.isEmpty
            }
        )
    }

    /// 执行代码动作（解析 lazy `edit`、应用 `WorkspaceEdit`、执行 `workspace/executeCommand`）
    func performAction(
        _ item: CodeActionItem,
        textView: TextView?,
        documentURL: URL?,
        applyWorkspaceEditViaTransaction: ((WorkspaceEdit) -> Void)? = nil,
        onFailureMessage: (String) -> Void
    ) async {
        switch item.payload {
        case .lsp(let action):
            await performLSPAction(
                action,
                textView: textView,
                documentURL: documentURL,
                applyWorkspaceEditViaTransaction: applyWorkspaceEditViaTransaction,
                onFailureMessage: onFailureMessage
            )
        case .plugin(let pluginAction):
            performPluginAction(
                pluginAction,
                textView: textView,
                onFailureMessage: onFailureMessage
            )
        }
    }

    private func performLSPAction(
        _ action: CodeAction,
        textView: TextView?,
        documentURL: URL?,
        applyWorkspaceEditViaTransaction: ((WorkspaceEdit) -> Void)? = nil,
        onFailureMessage: (String) -> Void
    ) async {
        var resolved = action

        if resolved.edit == nil, lspService.codeActionResolveSupported {
            if let r = await lspService.resolveCodeAction(resolved) {
                resolved = r
            }
        }

        if let edit = resolved.edit {
            // 优先走 transaction 路径（由 EditorState 提供），
            // 确保所有编辑行为走统一的 commitDocumentEditResult 后处理。
            if let applyViaTransaction = applyWorkspaceEditViaTransaction {
                applyViaTransaction(edit)
            } else {
                applyWorkspaceEdit(
                    edit,
                    textView: textView,
                    documentURL: documentURL,
                    onFailureMessage: onFailureMessage
                )
            }
            return
        }

        if let command = resolved.command {
            // 多数语言服务器在成功时返回 null；失败时由 LSPService 记录日志
            _ = await lspService.executeCommand(
                command: command.command,
                arguments: command.arguments
            )
            return
        }

        onFailureMessage(String(localized: "This code action has no edit or command", table: "LumiEditor"))
    }

    /// 清除
    func clear() {
        requestLifecycle.reset()
        actions.removeAll()
        isLoading = false
        isVisible = false
    }

    func reset() {
        requestLifecycle.reset()
    }

    private func sortCodeActionItems(_ items: [CodeActionItem]) -> [CodeActionItem] {
        items.sorted { a, b in
            if a.isPreferred != b.isPreferred { return a.isPreferred }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
    }

    private static func codeActionItem(from action: CodeAction) -> CodeActionItem? {
        guard action.disabled == nil else { return nil }
        return CodeActionItem(
            title: action.title,
            kind: action.kind ?? "",
            payload: .lsp(action),
            isPreferred: action.isPreferred == true
        )
    }

    private func performPluginAction(
        _ action: EditorCodeActionSuggestion,
        textView: TextView?,
        onFailureMessage: (String) -> Void
    ) {
        guard let textView else {
            onFailureMessage(String(localized: "No active editor", table: "LumiEditor"))
            return
        }
        guard let selection = textView.selectionManager.textSelections.first else {
            onFailureMessage(String(localized: "No selection to transform", table: "LumiEditor"))
            return
        }
        let range = selection.range
        guard range.location != NSNotFound, range.length > 0 else {
            onFailureMessage(String(localized: "No selection to transform", table: "LumiEditor"))
            return
        }
        guard let textRange = Range(range, in: textView.string) else {
            onFailureMessage(String(localized: "Invalid selection", table: "LumiEditor"))
            return
        }
        let selectedText = String(textView.string[textRange])

        let replacement: String
        switch action.command {
        case "builtin.swift.wrap-print":
            replacement = "print(\(selectedText))"
        case "builtin.swift.wrap-debug":
            replacement = """
            #if DEBUG
            \(selectedText)
            #endif
            """
        default:
            onFailureMessage(String(localized: "Unsupported editor plugin action", table: "LumiEditor"))
            return
        }

        textView.replaceCharacters(in: range, with: replacement)
    }

    // MARK: - WorkspaceEdit 应用

    private func applyWorkspaceEdit(
        _ edit: WorkspaceEdit,
        textView: TextView?,
        documentURL: URL?,
        onFailureMessage: (String) -> Void
    ) {
        var applied = false
        if let changes = edit.changes, let textView {
            for (uri, textEdits) in changes where Self.uriMatchesDocument(uri, documentURL: documentURL) {
                applyTextEdits(textEdits, to: textView)
                applied = true
            }
        }
        if !applied, let documentChanges = edit.documentChanges {
            applied = applyDocumentChangesReturningApplied(
                documentChanges,
                textView: textView,
                documentURL: documentURL
            )
        }
        if !applied {
            if edit.changes == nil && (edit.documentChanges == nil || edit.documentChanges?.isEmpty == true) {
                onFailureMessage(String(localized: "Empty workspace edit", table: "LumiEditor"))
            } else {
                onFailureMessage(String(localized: "No applicable edits for this file", table: "LumiEditor"))
            }
        }
    }

    @discardableResult
    private func applyDocumentChangesReturningApplied(
        _ changes: [WorkspaceEditDocumentChange],
        textView: TextView?,
        documentURL: URL?
    ) -> Bool {
        var applied = false
        for change in changes {
            switch change {
            case .textDocumentEdit(let docEdit):
                guard Self.uriMatchesDocument(docEdit.textDocument.uri, documentURL: documentURL) else { continue }
                guard let textView else { continue }
                applyTextEdits(docEdit.edits, to: textView)
                applied = true
            case .createFile(let operation):
                if WorkspaceEditFileOperations.applyCreateFile(operation) {
                    applied = true
                }
            case .renameFile(let operation):
                if WorkspaceEditFileOperations.applyRenameFile(operation) {
                    applied = true
                }
            case .deleteFile(let operation):
                if WorkspaceEditFileOperations.applyDeleteFile(operation) {
                    applied = true
                }
            }
        }
        return applied
    }

    private func applyTextEdits(_ edits: [TextEdit], to textView: TextView) {
        let sortedEdits = edits.sorted { lhs, rhs in
            let lStart = (lhs.range.start.line, lhs.range.start.character)
            let rStart = (rhs.range.start.line, rhs.range.start.character)
            return lStart > rStart
        }

        for edit in sortedEdits {
            if let nsRange = Self.nsRange(from: edit.range, in: textView.string) {
                textView.replaceCharacters(in: nsRange, with: edit.newText)
            }
        }
    }

    private static func uriMatchesDocument(_ documentUri: DocumentUri, documentURL: URL?) -> Bool {
        guard let documentURL else { return false }
        let normalizedDoc = documentURL.standardizedFileURL.absoluteString
        let normalizedTarget = normalizeFileURI(documentUri)
        if normalizedTarget == normalizedDoc { return true }
        if let u = URL(string: normalizedTarget) {
            return u.standardizedFileURL.path == documentURL.standardizedFileURL.path
        }
        return false
    }

    private static func normalizeFileURI(_ uri: String) -> String {
        if uri.hasPrefix("file:") {
            return URL(string: uri)?.standardizedFileURL.absoluteString ?? uri
        }
        if uri.hasPrefix("/") {
            return URL(fileURLWithPath: uri).standardizedFileURL.absoluteString
        }
        return uri
    }

    private static func nsRange(from lspRange: LSPRange, in content: String) -> NSRange? {
        let startLine = Int(lspRange.start.line)
        let startChar = Int(lspRange.start.character)
        let endLine = Int(lspRange.end.line)
        let endChar = Int(lspRange.end.character)

        guard startLine >= 0, endLine >= 0 else { return nil }

        let startOffset = Self.utf16Offset(line: startLine, character: startChar, in: content)
        let endOffset = Self.utf16Offset(line: endLine, character: endChar, in: content)

        guard let startOffset, let endOffset, endOffset >= startOffset else { return nil }
        return NSRange(location: startOffset, length: endOffset - startOffset)
    }

    private static func utf16Offset(line: Int, character: Int, in content: String) -> Int? {
        var currentLine = 0
        var offset = 0
        var lineStartOffset = 0

        for scalar in content.unicodeScalars {
            if currentLine == line {
                break
            }
            offset += scalar.utf16.count
            if scalar == "\n" {
                currentLine += 1
                lineStartOffset = offset
            }
        }

        guard currentLine == line else { return nil }
        return min(lineStartOffset + character, content.utf16.count)
    }
}

/// Code Action 数据模型
struct CodeActionItem: Identifiable {
    enum Payload {
        case lsp(CodeAction)
        case plugin(EditorCodeActionSuggestion)
    }

    let id = UUID()
    let title: String
    let kind: String
    let payload: Payload
    let isPreferred: Bool

    var icon: String {
        if kind == "plugin" {
            return "puzzlepiece.extension"
        }
        if kind.contains("quickfix") {
            return "lightbulb"
        } else if kind.contains("refactor") {
            return "arrow.triangle.2.circlepath"
        } else if kind.contains("source") {
            return "gearshape"
        }
        return "hammer"
    }
}

// MARK: - UI Views

/// 代码动作弹窗
struct CodeActionPanel: View {

    let actions: [CodeActionItem]
    @Binding var selectedIndex: Int
    let onActionSelected: (CodeActionItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppUI.Color.semantic.warning)
                Text("Code Actions")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if actions.indices.contains(selectedIndex),
                   actions[selectedIndex].isPreferred {
                    Text("Preferred")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(AppUI.Color.semantic.warning.opacity(0.14))
                        )
                }
                Text("\(actions.count) available")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppUI.Color.semantic.textTertiary.opacity(0.08))

            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        CodeActionRow(
                            action: action,
                            isSelected: index == selectedIndex,
                            onTap: {
                                selectedIndex = index
                                onActionSelected(action)
                            }
                        )

                        if index < actions.count - 1 {
                            Divider().opacity(0.2)
                        }
                    }
                }
            }
        }
        .frame(width: 380, height: min(CGFloat(actions.count) * 36 + 60, 300))
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            AppUI.Color.semantic.textPrimary.opacity(0.06),
                            AppUI.Color.semantic.textTertiary.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
        )
    }
}

/// 单个代码动作行
struct CodeActionRow: View {

    let action: CodeActionItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : AppUI.Color.semantic.textSecondary)
                    .frame(width: 16)

                Text(action.title)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white : AppUI.Color.semantic.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if action.isPreferred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .yellow : AppUI.Color.semantic.warning.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 6).fill(AppUI.Color.semantic.primary.opacity(0.9))
                    : RoundedRectangle(cornerRadius: 4).fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}

/// 灯泡指示器（显示在有问题的行号旁）
struct LightbulbIndicator: View {

    let hasActions: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "lightbulb")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(hasActions ? AppUI.Color.semantic.warning : AppUI.Color.semantic.textSecondary)
                .opacity(hasActions ? 1 : 0.3)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}
