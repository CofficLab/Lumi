//
//  FindMethodPicker.swift
//  EditorSource
//
//  Created by Austin Condiff on 5/2/25.
//

import SwiftUI

/// A SwiftUI view that provides a method picker for the find panel.
///
/// The `FindMethodPicker` view is responsible for:
/// - Displaying a dropdown menu to switch between different find methods
/// - Managing the selected find method
/// - Providing a visual indicator for the current method
/// - Adapting its appearance based on the control's active state
/// - Handling method selection
struct FindMethodPicker: NSViewRepresentable {
    @Binding var method: FindMethod
    @Environment(\.controlActiveState) var activeState
    var condensed: Bool = false

    private func createPopupButton(context: Context) -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.bezelStyle = .regularSquare
        popup.isBordered = false
        popup.controlSize = .small
        popup.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small))
        popup.autoenablesItems = false
        popup.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        popup.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        popup.title = method.displayName
        if condensed {
            popup.isTransparent = true
            popup.alphaValue = 0
        }
        return popup
    }

    private func createIconLabel() -> NSImageView {
        let imageView = NSImageView()
        let symbolName = method == .contains
            ? "line.horizontal.3.decrease.circle"
            : "line.horizontal.3.decrease.circle.fill"
        imageView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        imageView.contentTintColor = method == .contains
            ? (activeState == .inactive ? .tertiaryLabelColor : .labelColor)
            : (activeState == .inactive ? .tertiaryLabelColor : .controlAccentColor)
        return imageView
    }

    private func createChevronLabel() -> NSImageView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 8, weight: .black))
        imageView.contentTintColor = activeState == .inactive ? .tertiaryLabelColor : .secondaryLabelColor
        return imageView
    }

    private func createMenu(context: Context) -> NSMenu {
        let menu = NSMenu()

        // Add method items
        FindMethod.allCases.forEach { method in
            let item = NSMenuItem(
                title: method.displayName,
                action: #selector(Coordinator.methodSelected(_:)),
                keyEquivalent: ""
            )
            item.target = context.coordinator
            item.tag = FindMethod.allCases.firstIndex(of: method) ?? 0
            item.state = method == self.method ? .on : .off
            menu.addItem(item)
        }

        // Add separator before regular expression
        menu.insertItem(.separator(), at: 4)

        return menu
    }

    private func setupConstraints(
        container: NSView,
        popup: NSPopUpButton,
        iconLabel: NSImageView? = nil,
        chevronLabel: NSImageView? = nil
    ) {
        popup.translatesAutoresizingMaskIntoConstraints = false
        iconLabel?.translatesAutoresizingMaskIntoConstraints = false
        chevronLabel?.translatesAutoresizingMaskIntoConstraints = false

        var constraints: [NSLayoutConstraint] = []

        if condensed {
            constraints += [
                popup.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                popup.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                popup.topAnchor.constraint(equalTo: container.topAnchor),
                popup.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                popup.widthAnchor.constraint(equalToConstant: 36),
                popup.heightAnchor.constraint(equalToConstant: 20)
            ]
        } else {
            constraints += [
                popup.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                popup.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                popup.topAnchor.constraint(equalTo: container.topAnchor),
                popup.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ]
        }

        if let iconLabel = iconLabel {
            constraints += [
                iconLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                iconLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconLabel.widthAnchor.constraint(equalToConstant: 14),
                iconLabel.heightAnchor.constraint(equalToConstant: 14)
            ]
        }

        if let chevronLabel = chevronLabel {
            constraints += [
                chevronLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
                chevronLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                chevronLabel.widthAnchor.constraint(equalToConstant: 8),
                chevronLabel.heightAnchor.constraint(equalToConstant: 8)
            ]
        }

        NSLayoutConstraint.activate(constraints)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let popup = createPopupButton(context: context)
        popup.menu = createMenu(context: context)
        popup.selectItem(at: FindMethod.allCases.firstIndex(of: method) ?? 0)

        container.addSubview(popup)

        if condensed {
            let iconLabel = createIconLabel()
            let chevronLabel = createChevronLabel()
            container.addSubview(iconLabel)
            container.addSubview(chevronLabel)
            setupConstraints(container: container, popup: popup, iconLabel: iconLabel, chevronLabel: chevronLabel)
        } else {
            setupConstraints(container: container, popup: popup)
        }

        return container
    }

    /// 安全读取容器内指定序号的图片子视图。
    ///
    /// `makeNSView` 只在创建时按 `condensed` 添加图标和 chevron。SwiftUI 复用
    /// 容器后若层级与期望不一致，直接下标 `subviews[1]`/`subviews[2]` 会越界
    /// trap —— 外层 `as?` 发生在下标之后，无法保护越界。
    enum Subviews {
        static func imageView(at index: Int, in container: NSView) -> NSImageView? {
            guard container.subviews.indices.contains(index) else { return nil }
            return container.subviews[index] as? NSImageView
        }
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let popup = container.subviews.first as? NSPopUpButton else { return }

        // Update selection, title, and color
        popup.selectItem(at: FindMethod.allCases.firstIndex(of: method) ?? 0)
        popup.title = method.displayName
        popup.contentTintColor = activeState == .inactive ? .tertiaryLabelColor : .labelColor
        if condensed {
            popup.isTransparent = true
            popup.alphaValue = 0
        } else {
            popup.isTransparent = false
            popup.alphaValue = 1
        }

        // Update menu items state
        popup.menu?.items.forEach { item in
            let index = item.tag
            if index < FindMethod.allCases.count {
                item.state = FindMethod.allCases[index] == method ? .on : .off
            }
        }

        // Update icon and chevron colors
        if condensed {
            if let iconLabel = Subviews.imageView(at: 1, in: container) {
                let symbolName = method == .contains
                    ? "line.horizontal.3.decrease.circle"
                    : "line.horizontal.3.decrease.circle.fill"
                iconLabel.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
                iconLabel.contentTintColor = method == .contains
                    ? (activeState == .inactive ? .tertiaryLabelColor : .labelColor)
                    : (activeState == .inactive ? .tertiaryLabelColor : .controlAccentColor)
            }
            if let chevronLabel = Subviews.imageView(at: 2, in: container) {
                chevronLabel.contentTintColor = activeState == .inactive ? .tertiaryLabelColor : .secondaryLabelColor
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(method: $method)
    }

    var body: some View {
        self.fixedSize()
    }

    class Coordinator: NSObject {
        @Binding var method: FindMethod

        init(method: Binding<FindMethod>) {
            self._method = method
        }

        @objc func methodSelected(_ sender: NSMenuItem) {
            method = FindMethod.allCases[sender.tag]
        }
    }
}

#Preview("Find Method Picker") {
    FindMethodPicker(method: .constant(.contains))
        .padding()
}
