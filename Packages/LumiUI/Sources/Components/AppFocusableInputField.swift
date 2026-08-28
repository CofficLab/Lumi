import SwiftUI

/// 在 SwiftUI `List`(macOS 底层 NSTableView)行内也能正常获得焦点的输入框。
///
/// 背景:SwiftUI 的 `TextField`/`SecureField` 放进 macOS 的 `List` 后,点击输入框
/// 无法成为 first responder(NSTableView 的行选择/事件分发会拦截 cell 内的点击),
/// 表现为「点了没反应、光标不闪动」。`FocusState` + 手势组合在 List 内同样不可靠。
///
/// 本组件在 macOS 上用 `NSViewRepresentable` 包装原生 `NSTextField`/`NSSecureTextField`,
/// AppKit 控件的 `mouseDown` 直接走 `becomeFirstResponder`,点击即可聚焦,绕开
/// List 的拦截。视觉样式与 `AppInputField` 保持一致。
public struct AppFocusableInputField: View {
    public enum FieldType {
        case plain
        case secure
    }

    let placeholder: String
    @Binding var text: String
    let fieldType: FieldType

    public init(
        _ placeholder: String,
        text: Binding<String>,
        fieldType: FieldType = .plain
    ) {
        self.placeholder = placeholder
        self._text = text
        self.fieldType = fieldType
    }

    #if os(macOS)
    @LumiTheme private var theme

    public var body: some View {
        NativeFocusableTextField(
            text: $text,
            placeholder: placeholder,
            isSecure: fieldType == .secure,
            textColor: theme.textPrimary,
            placeholderColor: theme.textSecondary
        )
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(theme.appListRowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(theme.appSubtleBorder, lineWidth: 1)
        )
    }
    #else
    @LumiTheme private var theme

    public var body: some View {
        AppInputField(
            LocalizedStringKey(placeholder),
            text: $text,
            fieldType: fieldType == .secure ? .secure : .plain
        )
    }
    #endif
}

#if os(macOS)
import AppKit

/// 原生 NSTextField/NSSecureTextField 包装:点击直接成为 first responder。
private struct NativeFocusableTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let textColor: Color
    let placeholderColor: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isSecure: isSecure)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let field = makeField(context: context)
        context.coordinator.field = field
        container.addSubview(field)
        pinEdges(field, in: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        let field: NSTextField

        // plain ↔ secure 切换:原生字段类型不可变,需要重建。
        if coordinator.isSecure != isSecure {
            coordinator.field?.removeFromSuperview()
            field = makeField(context: context)
            coordinator.field = field
            nsView.addSubview(field)
            pinEdges(field, in: nsView)
            coordinator.isSecure = isSecure
        } else if let existing = coordinator.field {
            field = existing
        } else {
            field = makeField(context: context)
            coordinator.field = field
            nsView.addSubview(field)
            pinEdges(field, in: nsView)
        }

        if field.stringValue != text {
            field.stringValue = text
        }
        field.placeholderString = placeholder
        field.isEnabled = context.environment.isEnabled
        field.textColor = nsColor(textColor)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: nsColor(placeholderColor)]
        )
    }

    private func makeField(context: Context) -> NSTextField {
        let field: NSTextField
        if isSecure {
            field = ClickToFocusSecureTextField()
        } else {
            field = ClickToFocusTextField()
        }
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.font = NSFont.systemFont(ofSize: 15)
        field.stringValue = text
        field.placeholderString = placeholder
        field.textColor = nsColor(textColor)
        return field
    }

    private func pinEdges(_ view: NSView, in container: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func nsColor(_ color: Color) -> NSColor {
        guard let cg = color.cgColor else { return .labelColor }
        return NSColor(cgColor: cg)?.usingColorSpace(.deviceRGB) ?? .labelColor
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        weak var field: NSTextField?
        var isSecure: Bool

        init(text: Binding<String>, isSecure: Bool) {
            self.text = text
            self.isSecure = isSecure
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            if text.wrappedValue != field.stringValue {
                text.wrappedValue = field.stringValue
            }
        }
    }
}

/// 点击时先把 first responder 抢到自身再走默认 mouseDown,
/// 防止 List(NSTableView) 的行选择把点击事件吃掉。
private final class ClickToFocusTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

private final class ClickToFocusSecureTextField: NSSecureTextField {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
#endif
