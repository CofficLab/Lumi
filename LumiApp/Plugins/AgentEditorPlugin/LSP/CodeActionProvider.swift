import SwiftUI
import CodeEditSourceEditor
import CodeEditTextView
import LanguageServerProtocol

/// Code Action 提供者
/// 为诊断问题提供快速修复建议（灯泡图标）
@MainActor
final class CodeActionProvider: ObservableObject {

    private let lspService = LSPService.shared

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
        let codeActions = await lspService.requestCodeAction(uri: uri, range: range, diagnostics: diagnostics)
        isLoading = false

        actions = codeActions.compactMap { action -> CodeActionItem? in
            guard action.disabled == nil else { return nil }
            return CodeActionItem(
                title: action.title,
                kind: action.kind ?? "",
                action: action,
                isPreferred: action.isPreferred == true
            )
        }

        actions.sort { a, b in
            if a.isPreferred != b.isPreferred { return a.isPreferred }
            return a.title < b.title
        }

        isVisible = !actions.isEmpty
    }

    /// 请求针对某一行诊断的代码动作
    func requestCodeActionsForLine(
        uri: String,
        line: Int,
        character: Int,
        diagnostics: [Diagnostic],
        content: String
    ) async {
        let lineDiagnostics = diagnostics.filter { diag in
            Int(diag.range.start.line) <= line && Int(diag.range.end.line) >= line
        }

        guard !lineDiagnostics.isEmpty else {
            clear()
            return
        }

        guard let firstDiag = lineDiagnostics.first else {
            clear()
            return
        }

        await requestCodeActions(uri: uri, range: firstDiag.range, diagnostics: lineDiagnostics)
    }

    /// 执行代码动作（解析 lazy `edit`、应用 `WorkspaceEdit`、执行 `workspace/executeCommand`）
    func performAction(
        _ action: CodeAction,
        textView: TextView?,
        documentURL: URL?,
        onFailureMessage: (String) -> Void
    ) async {
        var resolved = action

        if resolved.edit == nil, lspService.codeActionResolveSupported {
            if let r = await lspService.resolveCodeAction(resolved) {
                resolved = r
            }
        }

        if let edit = resolved.edit {
            applyWorkspaceEdit(
                edit,
                textView: textView,
                documentURL: documentURL,
                onFailureMessage: onFailureMessage
            )
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
        actions.removeAll()
        isVisible = false
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
    let id = UUID()
    let title: String
    let kind: String
    let action: CodeAction
    let isPreferred: Bool

    var icon: String {
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
    let onActionSelected: (CodeAction) -> Void

    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("Code Actions")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(actions.count) available")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))

            Divider().opacity(0.3)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                        CodeActionRow(
                            action: action,
                            isSelected: index == selectedIndex,
                            onTap: {
                                selectedIndex = index
                                onActionSelected(action.action)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
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
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 16)

                Text(action.title)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if action.isPreferred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isSelected ? .yellow : .yellow.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor)
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
                .foregroundColor(hasActions ? .yellow : .secondary)
                .opacity(hasActions ? 1 : 0.3)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}
