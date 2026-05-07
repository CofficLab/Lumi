import SwiftUI

// MARK: - AppSearchBar

/// 统一的搜索栏组件：搜索图标 + 输入框 + 清除按钮
///
/// 用于替代 6+ 处重复的 `TextField + .textFieldStyle(.plain) + search icon` 模式。
///
/// ## 使用示例
/// ```swift
/// AppSearchBar(
///     text: $searchText,
///     placeholder: "搜索应用..."
/// )
///
/// // 带提交回调
/// AppSearchBar(
///     text: $searchText,
///     placeholder: "搜索 Homebrew 包...",
///     onSubmit: { performSearch() }
/// )
/// ```
struct AppSearchBar: View {
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    /// 基础初始化
    init(text: Binding<String>, placeholder: LocalizedStringKey) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = nil
    }

    /// 带提交回调的初始化
    init(text: Binding<String>, placeholder: LocalizedStringKey, onSubmit: @escaping () -> Void) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            // 输入框
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppUI.Typography.body)
                .foregroundColor(AppUI.Color.semantic.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            // 清除按钮
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
        .background(background)
        .cornerRadius(AppUI.Radius.sm)
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: AppUI.Radius.sm)
            .fill(AppUI.Material.glass)
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                    .stroke(isFocused ? AppUI.Color.semantic.primary.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview("AppSearchBar") {
    struct PreviewWrapper: View {
        @State private var searchText = ""
        var body: some View {
            VStack(spacing: 16) {
                AppSearchBar(text: $searchText, placeholder: "搜索应用...")
                
                AppSearchBar(text: $searchText, placeholder: "搜索 Homebrew 包...") {
                    print("执行搜索: \(searchText)")
                }
            }
            .padding()
            .frame(width: 400)
            .background(AppUI.Color.basePalette.deepBackground)
        }
    }
    return PreviewWrapper()
}