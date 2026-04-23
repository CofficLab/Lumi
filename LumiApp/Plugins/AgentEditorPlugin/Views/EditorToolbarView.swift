import SwiftUI
import MagicKit
import CodeEditTextView

/// 编辑器工具栏视图
/// 包含字体大小、缩进、主题切换等设置
struct EditorToolbarView: View {
    
    @ObservedObject var state: EditorState

    init(state: EditorState) {
        self._state = ObservedObject(wrappedValue: state)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 左侧：固定工具（字体大小 + 缩进）
            fontSizer
            
            Divider()
                .frame(height: 14)
            
            indentSettings
            
            Divider()
                .frame(height: 14)
            
            // 中间：切换开关（可压缩）
            toggleButtons

            ForEach(centerToolbarItems) { item in
                item.content(state)
            }

            Spacer(minLength: 0)

            ForEach(trailingToolbarItems) { item in
                item.content(state)
            }
            
            // 右侧：主题选择
            themePicker
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppUI.Color.semantic.textTertiary.opacity(0.06))
    }

    private var centerToolbarItems: [EditorToolbarItemSuggestion] {
        state.editorToolbarItems().filter { $0.placement == .center }
    }

    private var trailingToolbarItems: [EditorToolbarItemSuggestion] {
        state.editorToolbarItems().filter { $0.placement == .trailing }
    }
    
    // MARK: - Font Sizer
    
    private var fontSizer: some View {
        HStack(spacing: 2) {
            Text(String(localized: "A", table: "LumiEditor"))
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            
            Button {
                state.fontSize = max(10, state.fontSize - 1)
                state.persistConfig()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
            
            Text("\(Int(state.fontSize))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .frame(width: 24)
            
            Button {
                state.fontSize = min(28, state.fontSize + 1)
                state.persistConfig()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .frame(width: 20, height: 20)
        }
    }
    
    // MARK: - Indent Settings
    
    private var indentSettings: some View {
        Menu {
            Button("Tab (↹)") {
                state.useSpaces = false
                state.persistConfig()
            }
            
            Button("2 Spaces") {
                state.useSpaces = true
                state.tabWidth = 2
                state.persistConfig()
            }
            
            Button("4 Spaces") {
                state.useSpaces = true
                state.tabWidth = 4
                state.persistConfig()
            }
            
            Button("8 Spaces") {
                state.useSpaces = true
                state.tabWidth = 8
                state.persistConfig()
            }
        } label: {
            Image(systemName: "increase.indent")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .frame(height: 20)
    }
    
    // MARK: - Toggle Buttons
    
    private var toggleButtons: some View {
        HStack(spacing: 4) {
            // 自动换行
            ToolbarToggle(
                icon: "text.justify.leading",
                isActive: state.wrapLines
            ) {
                state.wrapLines.toggle()
                state.persistConfig()
            }
            
            // 行号
            ToolbarToggle(
                icon: "list.number",
                isActive: state.showGutter
            ) {
                state.showGutter.toggle()
                state.persistConfig()
            }
            
            // Minimap
            ToolbarToggle(
                icon: "rectangle.split.1x2",
                isActive: state.showMinimap
            ) {
                state.showMinimap.toggle()
                state.persistConfig()
            }
            
            // 多光标
            ToolbarToggle(
                icon: "cursorarrow.rays",
                isActive: state.multiCursorState.isEnabled
            ) {
                if state.multiCursorState.isEnabled {
                    state.clearMultiCursors()
                } else {
                    state.addNextOccurrence()
                }
                syncSelectionsToFocusedTextView()
            }
            .help(state.multiCursorState.isEnabled
                ? String(localized: "Clear Additional Cursors", table: "LumiEditor")
                : String(localized: "Add Next Occurrence", table: "LumiEditor"))
        }
    }
    
    // MARK: - Theme Picker
    
    private var themePicker: some View {
        Menu {
            ForEach(EditorThemeAdapter.PresetTheme.allCases, id: \.rawValue) { preset in
                Button {
                    state.setTheme(preset)
                } label: {
                    HStack {
                        Text(preset.displayName)
                        if state.themePreset == preset {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "paintbrush")
                .font(.system(size: 10))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 22, height: 22)
        }
        .menuStyle(.borderlessButton)
        .frame(height: 20)
    }

    private func syncSelectionsToFocusedTextView() {
        guard let responder = NSApp.keyWindow?.firstResponder else { return }
        guard let textView = responder as? TextView else { return }
        textView.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
    }
}

// MARK: - Toolbar Toggle Button

private struct ToolbarToggle: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(isActive ? AppUI.Color.semantic.primary : AppUI.Color.semantic.textTertiary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? AppUI.Color.semantic.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
