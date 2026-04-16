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
        
        // 按优先级排序
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
        // 找到该行的诊断并构建 range
        let lineDiagnostics = diagnostics.filter { diag in
            Int(diag.range.start.line) <= line && Int(diag.range.end.line) >= line
        }
        
        guard !lineDiagnostics.isEmpty else {
            clear()
            return
        }
        
        // 使用诊断的 range
        guard let firstDiag = lineDiagnostics.first else {
            clear()
            return
        }
        
        await requestCodeActions(uri: uri, range: firstDiag.range, diagnostics: lineDiagnostics)
    }
    
    /// 执行代码动作
    func executeAction(_ action: CodeAction, textView: TextView) {
        guard let edit = action.edit else {
            // 如果有 command，需要通过 LSP 执行
            if let command = action.command {
                // TODO: 执行 command
                print("Executing command: \(command.title)")
            }
            return
        }
        
        // 应用 WorkspaceEdit
        applyWorkspaceEdit(edit, textView: textView)
    }
    
    /// 清除
    func clear() {
        actions.removeAll()
        isVisible = false
    }
    
    // MARK: - WorkspaceEdit 应用
    
    private func applyWorkspaceEdit(_ edit: WorkspaceEdit, textView: TextView) {
        guard let changes = edit.changes else {
            // TODO: 处理 documentChanges
            return
        }
        
        // 对每个文件的编辑，按行倒序应用以避免偏移
        for (uri, textEdits) in changes {
            if let currentURI = lspService.activeLanguageId,
               uri == "\(currentURI)" || textView.string.contains("file:") {
                applyTextEdits(textEdits, to: textView)
            }
        }
    }
    
    private func applyTextEdits(_ edits: [TextEdit], to textView: TextView) {
        let content = textView.string
        // 按范围倒序排序，避免前面的编辑影响后面编辑的位置
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
    
    /// 图标（根据动作类型）
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
            // 标题
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
            
            // 动作列表
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
