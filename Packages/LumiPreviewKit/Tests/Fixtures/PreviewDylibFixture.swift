// MARK: - PreviewDylibFixture
//
// 最小化的"用户预览 dylib"源文件，仅用于手动验证 `Load Dylib…` 路径。
// 编译方法（在仓库根目录执行）：
//
//     SDK=$(xcrun --show-sdk-path --sdk macosx)
//     swiftc \
//       -emit-library \
//       -O \
//       -module-name PreviewDylibFixture \
//       -sdk "$SDK" \
//       -target arm64-apple-macosx14.0 \
//       -o /tmp/PreviewDylibFixture.dylib \
//       Packages/LumiPreviewKit/Tests/Fixtures/PreviewDylibFixture.swift
//
// 然后在 Lumi 中点 "Start Stream" → "Load Dylib…" 选择 `/tmp/PreviewDylibFixture.dylib`，
// 应当看到一个青色背景上跳动黄色圆点的视图。
//
// 符号约定：`@_cdecl("lumi_preview_make_nsview") () -> UnsafeMutableRawPointer?`
// 返回 `Unmanaged.passRetained(rootView).toOpaque()`，由子进程 `takeRetainedValue()` 接管所有权。

import AppKit
import SwiftUI

@MainActor
private final class FixtureState: ObservableObject {
    static let shared = FixtureState()

    private(set) var mouseDownCount = 0
    private(set) var keyDownCount = 0
    private(set) var dropCount = 0
    private(set) var lastKey = ""
    private(set) var lastDrop = ""
    @Published var firstText = ""
    @Published var secondText = ""
    @Published var focusedField = "none"
    private var usesManualInputFallback = false

    func recordMouseDown() {
        mouseDownCount += 1
    }

    func recordKeyDown(_ characters: String) {
        keyDownCount += 1
        lastKey = characters
    }

    func recordDrop(_ value: String) {
        dropCount += 1
        lastDrop = value
    }

    func beginManualInputFallbackIfNeeded() {
        guard focusedField == "none" else { return }
        focusedField = "first"
        usesManualInputFallback = true
    }

    func recordSwiftUIFocus(_ value: String) {
        focusedField = value
        usesManualInputFallback = false
    }

    func appendTextUsingManualFallbackIfNeeded(_ text: String) -> Bool {
        if focusedField == "none" {
            focusedField = "first"
            usesManualInputFallback = true
        }
        guard usesManualInputFallback else { return false }
        switch focusedField {
        case "second":
            secondText += text
        default:
            focusedField = "first"
            firstText += text
        }
        return true
    }

    var debugDescription: String {
        [
            "mouseDown=\(mouseDownCount)",
            "keyDown=\(keyDownCount)",
            "drop=\(dropCount)",
            "lastKey=\(lastKey)",
            "lastDrop=\(lastDrop)",
            "first=\(firstText)",
            "second=\(secondText)",
            "focus=\(focusedField)"
        ].joined(separator: ";")
    }
}

@MainActor
private final class FixtureProbeView: NSHostingView<FixtureRoot> {
    override var acceptsFirstResponder: Bool { true }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSCursor.pointingHand.set()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        NSCursor.pointingHand.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.pointingHand.set()
    }

    override func mouseDown(with event: NSEvent) {
        FixtureState.shared.recordMouseDown()
        FixtureState.shared.beginManualInputFallbackIfNeeded()
        super.mouseDown(with: event)
        NSCursor.pointingHand.set()
    }

    override func keyDown(with event: NSEvent) {
        let characters = event.characters ?? ""
        FixtureState.shared.recordKeyDown(characters)
        if FixtureState.shared.appendTextUsingManualFallbackIfNeeded(characters) {
            return
        }
        super.keyDown(with: event)
    }

    override func insertText(_ insertString: Any) {
        let text: String
        if let attributed = insertString as? NSAttributedString {
            text = attributed.string
        } else {
            text = String(describing: insertString)
        }
        FixtureState.shared.recordKeyDown(text)
        if FixtureState.shared.appendTextUsingManualFallbackIfNeeded(text) {
            return
        }
        super.insertText(insertString)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let string = pasteboard.string(forType: .string) {
            FixtureState.shared.recordDrop(string)
            return true
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first {
            FixtureState.shared.recordDrop(first.path)
            return true
        }
        return false
    }
}

private struct FixtureRoot: View {
    enum Field: Hashable {
        case first
        case second
    }

    @ObservedObject private var state = FixtureState.shared
    @FocusState private var focusedField: Field?

    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Color(nsColor: .systemTeal).opacity(0.6)

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 60, height: 60)
                    .offset(
                        x: CGFloat(sin(phase * 1.6)) * 80,
                        y: CGFloat(cos(phase * 1.6)) * 60
                    )

                VStack(spacing: 6) {
                    Text("PreviewDylibFixture")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Loaded via dlopen at \(Int(phase) % 1000)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                    VStack(spacing: 4) {
                        TextField("First", text: $state.firstText)
                            .focused($focusedField, equals: .first)
                        TextField("Second", text: $state.secondText)
                            .focused($focusedField, equals: .second)
                    }
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                }
                .padding(8)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
            .onAppear {
                focusedField = .first
            }
            .onHover { inside in
                if inside {
                    NSCursor.pointingHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .onChange(of: focusedField) { newValue in
                switch newValue {
                case .first:
                    state.recordSwiftUIFocus("first")
                case .second:
                    state.recordSwiftUIFocus("second")
                case nil:
                    state.recordSwiftUIFocus("none")
                }
            }
        }
    }
}

@_cdecl("lumi_preview_make_nsview")
@MainActor
public func lumi_preview_make_nsview() -> UnsafeMutableRawPointer? {
    let view = FixtureProbeView(rootView: FixtureRoot())
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("lumi_preview_debug_state")
@MainActor
public func lumi_preview_debug_state() -> UnsafeMutableRawPointer? {
    let state = FixtureState.shared.debugDescription
    return Unmanaged.passRetained(NSString(string: state)).toOpaque()
}
